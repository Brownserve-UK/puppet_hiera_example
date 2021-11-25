# Class: common::standard_users
# Creates users on Linux/Windows manchines.
#
#
class common::users
(
  Hash $users
)
{
  if !($::osfamily == 'windows')
  {
    package { 'sudo':
      ensure => present
    }
    group { 'group_wheel':
      ensure => present,
      name   => 'wheel',
    }
    # Don't purge the current sudo'ers file
    class { 'sudo':
      purge               => false,
      config_file_replace => false,
      require             => Package['sudo']
    }
    # Give our admin group some sensible sudo permissions, and get Puppet on the PATH while we're there.
    sudo::conf {'Wheel local admins':
      priority => 9,
      content  => file('common/linux/wheel.conf')
    }
    # Collect any sudoers that have been defined elsewhere
    Sudo::Conf <| tag == $::hostname |>
  }
  $users.each | String $name, Hash $value | {
    common::user {$name:
      ensure               => $value['ensure'],
      linux_groups         => $value['linux_groups'],
      windows_groups       => $value['windows_groups'],
      ssh_keys             => $value['ssh_keys'],
      password             => $value['password'],
      administrator        => $value['administrator'],
      bash_profile_content => file('common/linux/bashprofile')
    }
  }
}
