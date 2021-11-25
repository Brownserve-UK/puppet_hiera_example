# Class: common::linux
#@Summary Common things that should be applied to all linux machine
#
class common::linux
(
  $unattended_upgrades = true,
  $update_reboot = true,
  $update_reboot_time = '04:00',
  $update_schedule = 3,
)
{
  $packages = $::osfamily ? {
    # No builtin package for molly-guard and htop on RedHat based distros
    'RedHat' => ['nano', 'vim', 'unzip'],
    'Debian' => ['nano', 'vim', 'unzip', 'htop', 'molly-guard'],
    default  => ['nano', 'vim', 'unzip', 'htop', 'molly-guard'],
  }
  package { $packages:
    ensure => latest,
  }
  # Set some kernel panic error handling
  file {'/etc/sysctl.d/10-kernel-panic.conf':
    ensure => present,
    source => 'puppet:///modules/common/linux/10-kernel-panic.conf',
  }

  if($::osfamily == 'Debian') and ($unattended_upgrades) {
  #requires https://forge.puppet.com/puppet/unattended_upgrades
  # we should work out what we do for error handling here!
    class {'::unattended_upgrades':
      upgrade => $update_schedule, # Run the "unattended-upgrade" security upgrade script every n days (defaults to 3)
      auto    => {
        'clean'       => 7,                     # Auto clean undownloadable packages from cache every 7 days
        'reboot'      => $update_reboot,        # Whether to auto reboot the system or not. Defaults to true
        'reboot_time' => $update_reboot_time,   # Time to reboot. Defaults to 0400
        'remove'      => true                   # Auto remove unused dependencies
      }
    }
  } else {
    warning("Not a Debian based OS (${::os['family']}). Cannot setup unattended_upgrades")
  }
}
