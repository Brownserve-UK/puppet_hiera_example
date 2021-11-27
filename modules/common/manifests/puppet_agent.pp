# Manage puppet agent version and configuration
#
# @param package_ensure
#   The version of puppet agent to install, if latest it will auto-update to the latest version available 
#   (this is a bad idea on Windows as it results in jumping between major versions of Puppet)
# @param puppet_agent_options
#   a Hash of options that will be set in the puppet config file
class common::puppet_agent(
  $package_ensure = 'present',
  $puppet_agent_options = {'splay' => true},
  ) {

  # We need to do this as this module can be called before we've got chocolatey installed :(
  if ($::osfamily == 'windows')
  {
    $provider = 'chocolatey'
    require common::windows
  }
  else
  {
    $provider = undef
  }
  package { 'puppet-agent':
    ensure   => $package_ensure,
    provider => $provider
  }

  $puppet_agent_options.each | $option_name, $option_value| {
    # ini_setting { "puppet.conf-${option_name}":
    #   ensure  => present,
    #   path    => $::puppet_config,
    #   section => 'agent',
    #   setting => $option_name,
    #   value   => $option_value,
    #   notify  => Service['puppet'],
    # }
  }

  service {'puppet':
    ensure => running,
  }
}
