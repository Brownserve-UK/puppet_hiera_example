# @summary Installs and configures Puppetserver on a node
# 
# @param puppet_majorversion
#   The major version of Puppet to install
# @param puppet_environment
#   The environment to be set for this node in puppet.conf
# @param puppet_user
#   The user to run Puppet as (defaults to puppet)
# @param puppet_group
#   The group to run Puppet as (defaults to puppet)
# @param hiera_yaml_path
#   Used by both ::hiera and ::puppet class because they both try
#   to manage the hiera_config setting in puppet.conf
#   https://puppet.com/docs/puppet/latest/lang_facts_builtin_variables.html
# @param puppet_dbserver
#   The hostname of the PuppetDB server (defaults to this node)
# @param install_puppetdb
#   Whether to install PuppetDB (defaults to true)
class puppetserver
(
  $puppet_majorversion,
  $puppet_environment,
  $puppet_user = 'puppet',
  $puppet_group = 'puppet',
  $hiera_yaml_path = "${::settings::codedir}/hiera.yaml",
  Boolean $install_puppetdb = true,
  $puppet_dbserver = $::fqdn,
)
{
  include puppetserver::codemanagement
  include puppetserver::firewall
  include common::ntpclient

  # Ensure the 'puppet' user and group are present
  group { $puppet_group:
    ensure => present,
  }
  -> user { $puppet_user:
      ensure => present,
      groups => $puppet_group,
      shell  => '/usr/sbin/nologin',
    }

  # We're very specific about what values we set to both avoid automatically breaking things and to give us a stable
  # bootstrap environment.
  case $puppet_majorversion
  {
    7:
    {
      # Versions can be found here https://puppet.com/docs/puppet/7/server/release_notes.html
      $puppetserver_version = '7.4.2'
      $puppetserver_package_version = "7.4.2-1${::lsbdistcodename}"
      # Versions can be found here https://puppet.com/docs/puppetdb/7/release_notes.html
      $puppetdb_package_version = "7.7.1-1${::lsbdistcodename}"
      # Minium of 11, supported versions can be found at https://puppet.com/docs/puppetdb/7/overview.html
      $postgres_version = '14'
      # Do not let puppet upgrade to the latest version of puppet-agent.
      # That's because for major upgrades, we are supposed to upgrade puppetserver
      # before puppet-agent.
      $puppet_agent_package_version = "7.12.1-1${::lsbdistcodename}"
      # Hiera 5 is the current latest version of Hiera
      $hiera_version = '5'
      # with hiera v5, hierarchies should be defined in the environment and module layers
      # hiera.yaml files which are committed with our puppet source code.
      $hiera_hierarchies = []
      # Versions can be found at https://github.com/voxpupuli/hiera-eyaml/tags
      $eyaml_version = '3.2.2'
      # Picked default cipher_suites values from https://github.com/theforeman/puppet-puppet/pull/721
      $cipher_suites = [
        'TLS_DHE_RSA_WITH_AES_128_GCM_SHA256',
        'TLS_DHE_RSA_WITH_AES_256_GCM_SHA384',
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256',
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
      ]
    }
    6:
    {
        # Check what versions are supported at https://puppet.com/docs/puppetdb/6/overview.html
      $postgres_version = '12'
      # Versions can be found at https://puppet.com/docs/puppet/6/server/release_notes.html
      $puppetserver_version = '6.17.1'
      $puppetserver_package_version = "6.17.1-1${::lsbdistcodename}"
      # Versions can be found at https://puppet.com/docs/puppetdb/6/release_notes.html
      $puppetdb_package_version = "6.19.1-1${::lsbdistcodename}"
      # Do not let puppet upgrade to the latest version of puppet-agent.
      # That's because for major upgrades, we are supposed to upgrade puppetserver
      # before puppet-agent.
      $puppet_agent_package_version = "6.25.1-1${::lsbdistcodename}"
      # Hiera 5 is the current latest version of Hiera
      $hiera_version = '5'
      # with hiera v5, hierarchies should be defined in the environment and module layers
      # hiera.yaml files which are committed with our puppet source code.
      $hiera_hierarchies = []
      # Versions can be found at https://github.com/voxpupuli/hiera-eyaml/tags
      $eyaml_version = '3.2.2'
      # Picked default cipher_suites values from https://github.com/theforeman/puppet-puppet/pull/721
      $cipher_suites = [
        'TLS_DHE_RSA_WITH_AES_128_GCM_SHA256',
        'TLS_DHE_RSA_WITH_AES_256_GCM_SHA384',
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256',
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
      ]
    }
    default:
    {
      fail("Unsupported Puppet version: ${puppet_majorversion}.")
    }
  }

  # On bootstrap installations puppetdb will fail to start, this is because the ssl keys are not generated during a 'puppet apply'
  # they are only created on 'puppet agent -t' or 'puppet ssl bootstrap'
  # Therefore we need a way to _not_ set-up PuppetDB until after we first run Puppet
  if ($install_puppetdb)
  {
    # Install and configure PuppetDB
    class { 'puppetdb::globals':
      version => $puppetdb_package_version,
    }

    class { 'puppetdb':
      node_ttl           => '14d',
      node_purge_ttl     => '30d',
      report_ttl         => '5d',
      # Make the Java VM use less RAM (adjust for your environment)
      java_args          => {
        '-Xmx' => '1g',
        '-Xms' => '1g',
      },
      postgres_version   => $postgres_version,
      # ciphers used between puppetserver and puppetdb. They do need to match
      cipher_suites      => join($cipher_suites, ', '),
      ssl_deploy_certs   => true,
      ssl_dir            => '/etc/puppetlabs/puppetdb/ssl',
      ssl_set_cert_paths => true,
    }
    $puppet_require = [Class['puppetdb']]
    $server_reports = 'puppetdb'
    $server_storeconfigs = true
  }
  else
  {
    $puppet_require = undef
    $server_reports = undef
    $server_storeconfigs = undef
  }

  if $::trusted['extensions']['pp_environment'] == 'live' {
    $puppet_tuning_parameters = {
      # Puppet server tuning. See https://puppet.com/docs/puppetserver/latest/tuning_guide.html
      # Set max active JRuby instances. (how many Puppet runs can happen at once)
      # Generally this should equal CPU count, howerver as my env is small 1 is enough, 2 for safety
      server_max_active_instances    => 2,
      # Set heap size. Recommendation is (512MB * max_active_instances) + 'a bit'.
      # Therefor I have set mimimun to 1G and given a max of 2G.
      # This is equivelent to setting JAVA_ARGS="-xms1g -xmx2g" in /etc/default/puppetserver
      server_jvm_min_heap_size       => '1G',
      server_jvm_max_heap_size       => '2G',
      # Set ReservedCodeCache to 1G (recommended when working with 6-12 JRuby instances)
      # Not needed in my case, but could potentially be LOWERED in the future! 
      # server_jvm_extra_args          => '-XX:ReservedCodeCacheSize=1G',
    }
  }
  else
  {
    $puppet_tuning_parameters = {
      # When in a testing/dev environment we want to use less resources
      server_max_active_instances => 1,
      server_jvm_min_heap_size => '512m',
      server_jvm_max_heap_size => '1G',
    }
  }

  # Install and configure puppet-agent, puppet-server and foreman
  # will manage Java Memory settings in /etc/default/puppetserver
  class { '::puppet':
    # install puppet server
    server                      => true,
    # The version of the puppet-agent package.
    version                     => $puppet_agent_package_version,
    # the version of the puppetserver package.
    server_version              => $puppetserver_package_version,
    # used by foreman to setup the correct config options.
    server_puppetserver_version => $puppetserver_version,
    # ciphers used between puppetserver and puppetdb. They do need to match
    server_cipher_suites        => $cipher_suites,
    # Which Puppet environment to use
    environment                 => $puppet_environment,
    # disable integration with foreman
    server_foreman              => false,
    # disable getting external nodes from foreman
    server_external_nodes       => '',
    # only store the reports in the puppetdb
    server_reports              => $server_reports,
    server_storeconfigs         => $server_storeconfigs,
    server_user                 => $puppet_user,
    server_group                => $puppet_group,
    # We do not use a list of common modules to be shared between environments
    server_common_modules_path  => [],
    # The ::puppet class defaults hiera_config to the wrong value for puppet > 4.5
    # At the time of writing, puppet version is 4.5.3. Hardcode hiera_config here.
    hiera_config                => $hiera_yaml_path,

    # Manage additional puppet.conf settings:
    # [main] section
    additional_settings         => {
      # So that we will see failure to retrieve/compile the catalog
      # As run failure on our puppet board for all agents.
      # https://puppet.com/docs/puppet/latest/configuration.html#usecacheonfailure
      usecacheonfailure => false,
      },
    # [agent] section
    agent_additional_settings   => {},
    # [master] section
    server_additional_settings  => {},

    # because ::puppet does set usecacheonfailure in the [agent] section as well.
    usecacheonfailure           => false,

    # We manage $puppet_user ourselves thank you very much.
    server_manage_user          => false,

    *                           => $puppet_tuning_parameters,

    require                     => $puppet_require,
  }

  if ($install_puppetdb)
  {
    # Will manage puppetdb.conf for us
    class { 'puppet::server::puppetdb':
      server  => $puppet_dbserver,
      require => $puppet_require
    }
  }

  class {'hiera':
    hiera_yaml     => $hiera_yaml_path,
    hiera_version  => $hiera_version,
    hierarchy      => $hiera_hierarchies,
    eyaml          => true,
    eyaml_version  => $eyaml_version,
    datadir        => '/etc/puppetlabs/code/environments',
    eyaml_datadir  => '/etc/puppetlabs/code/environments',
    datadir_manage => false,
    provider       => 'puppetserver_gem',
    # don't want a symlink at /etc/hiera.yaml as this breaks our tests
    create_symlink => false,
    # restart puppetserver so that puppet picks up the hiera config changes.
    master_service => 'puppetserver',
    require        => User[$puppet_user],
  }

  # Add a symlink to the eyaml binary to /opt/puppetlabs/bin/ which is already
  # included in the system PATH
  file {'/opt/puppetlabs/bin/eyaml':
    ensure  => link,
    target  => '/opt/puppetlabs/puppet/bin/eyaml',
    require => Class['hiera'],
  }
}
