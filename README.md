# Perl-SSH-Task
================

A Parallel Remote Command Tool.

### SYNOPSIS

```

# show mini help
 $ perl ssh_task.pl

# show registered servers generated by ./servers.conf
 $ perl ssh_task.pl --server-list

# show registered general tasks generated by ./tasks.conf
 $ perl ssh_task.pl --task-list

# execute registered command for registered remote servers or server labels
 $ perl ssh_task.pl my_server_01 my_secret_command_01
 $ perl ssh_task.pl my_favorit_servers my_secret_command_01

# execute registered command for all registered servers
 $ perl ssh_task.pl all my_secret_command_02

# execute given remote command 
 $ perl ssh_task.pl my_server_01 do "uname -a"

# execute given remote command as sudo
 $ perl ssh_task.pl my_server_01 do_sudo reboot

```

### INSTALLATION and CONFIGURING

```

# 1. Clone this repository.
 $ git clone https://github.com/adokoy001/Perl-SSH-Task.git ./my_ssh_task
 $ cd my_ssh_task


# 2. Configure tasks.conf
 $ vim tasks.conf

   #{
   #        server_info => [
   #            ["hostname"],
   #            ["uname -a"],
   #            ["ifconfig"],
   #            ["free"],
   #            ["cat /proc/cpuinfo | grep processor"],
   #            ["uptime"]
   #           ],
   #        upgrade_apt => [
   #            [ {stdin_data => "$servers->{$server_name}->{password}\n"} , "sudo -Sk -p '' "."apt-get update"],
   #            [ {stdin_data => "$servers->{$server_name}->{password}\n"} , "sudo -Sk -p '' "."apt-get upgrade -y"]
   #           ],
   #        .
   #        .
   #        .
   #}


# 3. Configure servers.conf
 $ vim servers.conf

   #{
   #    my_server_01 => {
   #        label => ['internal','development','my_favorite'],
   #        host => 'localhost',
   #        port => 22,
   #        user => 'myname',
   #        password => 'mypassword',
   #        general_task => {
   #            server_info => 'server_info',
   #            upgrade => 'upgrade_apt',
   #            reboot => 'reboot'
   #           },
   #        specified_task => {
   #            test_1 => [["~/.plenv/shims/perl -v"]],
   #            test_1 => [["~/.plenv/shims/perl global"]]
   #           }
   #       },
   #       .
   #       .
   #       .
   #}


# 4. Configure config.conf if needed
 $ vim config.conf

   #{
   #    max_fork_num => 20,
   #    servers_conf_file => './servers.conf',
   #    tasks_conf_file => './tasks.conf',
   #}


# 5. Install Required Perl Modules if needed
 $ cpanm --installdeps .

```

