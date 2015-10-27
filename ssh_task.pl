use strict;
use warnings;
use Safe;
use Net::OpenSSH;
use Parallel::ForkManager;

my $target_label = $ARGV[0];
my $task = $ARGV[1];
my $do_command = $ARGV[2] || "echo 'command is not defined.'";

# Print Usage when no args given
unless(defined($target_label)){
    print "Usage:\n";
    print "perl ssh_task.pl <list_name>\n";
    print "  perl ssh_task.pl --server-list\n";
    print "  perl ssh_task.pl --task-list\n";
    print "perl ssh_task.pl <target or all> <task_name>\n";
    print "  perl ssh_task.pl my_server_name view_info\n";
    print "  perl ssh_task.pl my_label_name reboot\n";
    print "perl ssh_task.pl <target or all> <do,do_sudo,do_sudo_tty> <command>\n";
    print "  perl ssh_task.pl my_label_name do \"uname -a\"\n";
    print "  perl ssh_task.pl my_label_name do_sudo reboot\n";
    print "  perl ssh_task.pl my_label_name do_sudo_tty reboot\n\n";
    exit;
}

# For safe eval
my $safe = Safe->new;
$safe->permit(qw(time sort));

# Read config.conf to scalar variable.
my $config_file_content;
open(my $fh_config,"<./config.conf") or die "$!$@";
while(<$fh_config>){$config_file_content .= $_;}
close($fh_config);

# Safe eval. create $config.
my $config = $safe->reval($config_file_content) or die "$!$@";

# Read *.conf files defined at config.conf
my $servers_file = $config->{servers_conf_file} || './servers.conf';
my $tasks_file = $config->{tasks_conf_file} || './tasks.conf';
my $fork_num = $config->{max_fork_num} || 20;

my $servers_file_content;
open(my $fh_servers,"<$servers_file") or die "$!$@";
while(<$fh_servers>){$servers_file_content .= $_;}
close($fh_servers);

my $servers = $safe->reval($servers_file_content) or die "$!$@";

my $tasks_file_content;
open(my $fh_tasks,"<$tasks_file") or die "$!$@";
while(<$fh_tasks>){$tasks_file_content .= $_;}
close($fh_tasks);

# Set OpenSSH option StrictHostKeyChecking.
my $strict_host_key = 'StrictHostKeyChecking=yes';
if(defined($config->{StrictHostKeyChecking}) and $config->{StrictHostKeyChecking} eq 'no'){
    $strict_host_key = 'StrictHostKeyChecking=no';
}

if($target_label eq '--server-list'){
    # Show defined servers when 1st argument is '--server-list'
    my $counter=0;
    foreach my $key (sort keys %$servers){
	$counter++;
	my @specified_tasks;
	foreach my $key2 (sort keys %{$servers->{$key}->{specified_task}}){
	    push(@specified_tasks,$key2);
	}
	my @labels = @{$servers->{$key}->{label}};
	print "---- [$key] ----\n";
	print "  HOST: $servers->{$key}->{host}\n";
	print "  PORT: $servers->{$key}->{port}\n";
	print "  USER: $servers->{$key}->{user}\n";
	print "  PASSWORD: $servers->{$key}->{password}\n";
	print "  LABEL: [".(join(',',@labels))."]\n";
	print "  SPECIFIED TASK: [".(join(',',@specified_tasks))."]\n";
    }
    print "$counter server(s) registered.\n";
    exit;
}elsif($target_label eq '--task-list'){
    # Show defined servers when 1st argument is '--task-list'
    my $command_template = $safe->reval($tasks_file_content) or die "$!$@";
    my $counter=0;
    foreach my $key (sort keys %$command_template){
	$counter++;
	print " - $key\n";
    }
    print "$counter general task(s) registered.\n";
    exit;
}

# When no task given...
unless(defined($task)){
    print "please give me a task\n";
    exit;
}

# Do eval for each server for general_task and specified_task
foreach my $server_name (sort keys %$servers){
    my $command_template = $safe->reval($tasks_file_content) or die "$!$@";
    my $task_tmp;
    foreach my $general_task (sort keys %{$servers->{$server_name}->{general_task}}){
	$task_tmp->{$general_task} = $command_template->{$servers->{$server_name}->{general_task}->{$general_task}};
    }
    foreach my $specified_task (sort keys %{$servers->{$server_name}->{specified_task}}){
	$task_tmp->{$specified_task} = $servers->{$server_name}->{specified_task}->{$specified_task};
    }
    # Add 'do' task
    $task_tmp->{do} = [[$do_command]];
    $task_tmp->{do_sudo} = [[{stdin_data => "$servers->{$server_name}->{password}\n"} , "sudo -Sk -p '' ".$do_command]];
    $task_tmp->{do_sudo_tty} = [[{tty => 1, stdin_data => "$servers->{$server_name}->{password}\n"} , "sudo -k -p '' ".$do_command]];
    $servers->{$server_name}->{task} = $task_tmp;
}

# Results
my $results = {
    proceeded_server => 0,
    ignored_server => 0,
   };

my $server_matched=0;

# Parallel processing by using fork.
my $pm = Parallel::ForkManager->new($fork_num);

# Main procedure.
# This foreach loop try to match server name or defined labels and given 1st argument.
foreach my $server (sort keys %$servers){
    my $label_ref = $servers->{$server}->{label} || [];
    my $flag = 0;
    if($target_label eq 'all'){
	$flag = 1;
	$server_matched=1;
    }elsif($server eq $target_label){
	$flag = 1;
	$server_matched=1;
    }else{
	for(my $k=0; $k <= $#$label_ref; $k++){
	    if($label_ref->[$k] eq $target_label){
		$flag = 1;
		$server_matched=1;
		last;
	    }
	}
    }
    # Case: server matched but task unmatched.
    if(($flag == 1) and (!defined($servers->{$server}->{task}->{$task}))){
	$flag = 0;
	print "\033[30m\033[46m[$server / $servers->{$server}->{host}]:\033[0m\033[31m Undefined task name: $task\033[0m\n\n";
    }
    # Proceed given task
    if($flag == 1){
	$results->{proceeded_server}++;
	my $pid = $pm->start and next;
	my $ssh = Net::OpenSSH->new(
	    $servers->{$server}->{host},
	    master_opts => [-o => $strict_host_key],
	    port => $servers->{$server}->{port},
	    user => $servers->{$server}->{user},
	    password => $servers->{$server}->{password}
	   );
	if($ssh->error){
	    print "\033[30m\033[46m[$server / $servers->{$server}->{host}]:\033[0m\033[31m Can't connect to remote server.\033[0m\n\n";
	}else{
	    for(my $k = 0 ; $k <= $#{$servers->{$server}->{task}->{$task}}; $k++){
		my $command = $servers->{$server}->{task}->{$task}->[$k];
		my ($output,$error) = $ssh->capture2(@$command);
		my $step_message = 'Step '.($k+1).' of '.($#{$servers->{$server}->{task}->{$task}}+1);
		if($ssh->error){
		    print "\033[30m\033[46m[$server / $servers->{$server}->{host}]: $step_message\033[0m\n\033[31m$error\033[0m\n";
		}else{
		    print "\033[30m\033[46m[$server / $servers->{$server}->{host}]: $step_message\033[0m\n\033[32m$output\033[0m\n";
		}
	    }
	}
	$pm->finish;
    }else{
	$results->{ignored_server}++;
    }
}
# wait all child process.
$pm->wait_all_children;

if($server_matched == 0){
    print "NO SERVER MATCHED.\n";
    print "Try this command:\n";
    print "  perl ssh_task.pl --server-list\n";
}else{
    print "COMPLETED!\n";
    print "--- [SUMMARY] ---\n";
    print "PROCEEDED SERVER: \033[32m$results->{proceeded_server}\033[0m\n";
    print "IGNORED SERVERS : \033[31m$results->{ignored_server}\033[0m\n";
}
