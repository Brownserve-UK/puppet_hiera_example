# Class: puppetserver::puppetboard
# @summary
#   Installs and configures the Puppetboard dashboard
#
# @puppetboard_dir
#   The directory where the Puppetboard dashboard will be installed
# @puppetboard_version
#   The version of Puppetboard to install
class puppetserver::puppetboard
(
  String $puppetboard_dir,
  String $puppetboard_version
)
{
  include docker
  require puppetserver

  file { $puppetboard_dir:
    ensure => directory,
    mode   => '0755',
  }

  vcsrepo { $puppetboard_dir:
    ensure   => 'present',
    provider => git,
    source   => 'git://github.com/voxpupuli/puppetboard.git',
    revision => $puppetboard_version,
    require  => File[$puppetboard_dir],
  }

  docker::image { 'puppetboard':
    docker_file => "${puppetboard_dir}/Dockerfile",
    docker_dir  => $puppetboard_dir,
    image_tag   => $puppetboard_version,
    require     => Vcsrepo[$puppetboard_dir],
  }

  docker::run { 'puppetboard':
    image   => "puppetboard:${puppetboard_version}",
    labels  => ['puppetboard'],
    ports   => ['80:80'],
    volumes => ["${settings::ssldir}:/ssl"],
    env     => [
      "PUPPETDB_HOST=${::fqdn}",
      'PUPPETDB_PORT=8081',
      'PUPPETDB_SSL_VERIFY=/ssl/certs/ca.pem',
      "PUPPETDB_KEY=/ssl/private_keys/${::clientcert}.pem",
      "PUPPETDB_CERT=/ssl/certs/${::clientcert}.pem",
      #'PUPPETBOARD_URL_PREFIX=puppetboard', # you may wish to uncomment this if you'd like to have a prefix for your Puppetboard
      'ENABLE_CATALOG=True',
      'UNRESPONSIVE_HOURS=24',
    ],
    extra_parameters => "--add-host='${::fqdn}:${::ipaddress}'", # https://rollout.io/blog/using-the-add-host-flag-for-dns-mapping-within-docker-containers/
    require => Docker::Image['puppetboard'],
  }
}
