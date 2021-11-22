# Class: puppetserver::codemanagement
# @summary
#   Installs and configures r10k on a node
# @param r10k_version
#   The version of r10k to install (defaults to present)
class puppetserver::codemanagement
(
  $r10k_version = 'present'
)
{
  # r10k commands need to be executed as root.
  # So we are going to setup root so that it can pull from our github repos
  $username ='root'
  $home_folder = '/root'

  File {
    mode    => '0600',
    owner   => $username,
    group   => $username,
  }

  package { 'ruby':
    ensure => 'present',
  }
  -> package { 'r10k':
      ensure   => $r10k_version,
      provider => 'gem',
    }
  -> file { '/etc/puppetlabs/r10k':
      ensure => 'directory',
    }
  -> file { '/etc/puppetlabs/r10k/r10k.yaml':
      content => template('puppetserver/r10k.yaml.erb'),
    }

  cron { 'r10k deploy environment --puppetfile':
    ensure  => present,
    # r10k can hang especially if it's already running, this kills it on the off-chance it's already running. (side-effect is that it will kill any user initiated runs)
    command => '/usr/bin/pkill --echo --signal 9 r10k; /usr/local/bin/r10k deploy environment --puppetfile 2>&1 | logger -t "r10k_deploy_environment"',
    user    => $username,
    minute  => '*/15',
    require => File['/etc/puppetlabs/r10k/r10k.yaml'],
  }
}
