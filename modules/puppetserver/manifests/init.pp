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
class puppetserver
(
  $puppet_majorversion,
  $puppet_environment,
  $puppet_user = 'puppet',
  $puppet_group = 'puppet',
  $hiera_yaml_path = "${::settings::codedir}/hiera.yaml",
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

  # We lock the versions in to the below as we know they work at the time of writing. 
  # We can look to overwrite, make these more flexible in the future.
  if $puppet_majorversion == 6
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
  }
  else
  {
    fail("Unsupported Puppet version: ${puppet_majorversion}.")
  }

  # Install and configure PuppetDB
  class { 'puppetdb::globals':
    version => $puppetdb_package_version,
  }

  class { 'puppetdb':
    node_ttl         => '14d',
    node_purge_ttl   => '30d',
    report_ttl       => '5d',
    # do not disable ssl as it is needed in puppetdb.conf (server_urls)
    disable_ssl      => false,
    # Make the Java VM use less RAM (adjust for your environment)
    java_args        => {
      '-Xmx' => '1g',
      '-Xms' => '1g',
    },
    postgres_version => $postgres_version,
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
    # Which Puppet environment to use
    environment                 => $puppet_environment,
    # disable integration with foreman
    server_foreman              => false,
    # disable getting external nodes from foreman
    server_external_nodes       => '',
    # Will manage puppetdb.conf for us
    server_puppetdb_host        => $puppet_dbserver,
    # only store the reports in the puppetdb
    server_reports              => 'puppetdb',
    server_storeconfigs_backend => 'puppetdb',
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

    require                     => [Class['puppetdb']],
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
