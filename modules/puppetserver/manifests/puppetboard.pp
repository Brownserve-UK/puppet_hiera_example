# Class: puppetserver::puppetboard
# @summary
#   Installs and configures the Puppetboard dashboard
#
# @param puppetboard_dir
#   The directory where the Puppetboard dashboard will be installed
# @param puppetboard_version
#   The version of Puppetboard to install
class puppetserver::puppetboard (
  String $puppetboard_version = '5.4.0',
  String $puppetboard_dir = '/srv/puppetboard',
) {
  include docker
  require puppetserver

  file { $puppetboard_dir:
    ensure => directory,
    mode   => '0755',
  }

  # We build the Docker image off of the Dockerfile located in the Voxpupuli repo
  vcsrepo { $puppetboard_dir:
    ensure   => 'present',
    provider => git,
    source   => 'https://github.com/voxpupuli/puppetboard.git',
    revision => "v${puppetboard_version}",
    require  => File[$puppetboard_dir],
  }

  # Build the image and tag it with the version number
  docker::image { 'puppetboard':
    docker_file => "${puppetboard_dir}/Dockerfile",
    docker_dir  => $puppetboard_dir,
    image_tag   => $puppetboard_version,
    require     => Vcsrepo[$puppetboard_dir],
  }

  # Run said image
  docker::run { 'puppetboard':
    image            => "puppetboard:${puppetboard_version}",
    labels           => ['puppetboard'],
    ports            => ['80:80'],
    volumes          => ["${settings::ssldir}:/ssl"],
    env              => [
      "PUPPETDB_HOST=${facts['networking']['fqdn']}",
      'PUPPETDB_PORT=8081',
      'PUPPETDB_SSL_VERIFY=/ssl/certs/ca.pem',
      "PUPPETDB_KEY=/ssl/private_keys/${facts['clientcert']}.pem",
      "PUPPETDB_CERT=/ssl/certs/${facts['clientcert']}.pem",
      #'PUPPETBOARD_URL_PREFIX=puppetboard', # you may wish to uncomment this if you'd like to have a prefix for your Puppetboard
      'ENABLE_CATALOG=True',
      'UNRESPONSIVE_HOURS=24',
      # See https://flask.palletsprojects.com/en/stable/quickstart/#sessions for information
      # on how to generate a secret key
      # The below is just an md5 of 'Hello world'
      'SECRET_KEY=64EC88CA00B268E5BA1A35678A1B5316D212F4F366B2477232534A8AECA37F3C'
    ],
    # https://rollout.io/blog/using-the-add-host-flag-for-dns-mapping-within-docker-containers/
    extra_parameters => "--add-host='${facts['networking']['fqdn']}:${facts['networking']['ip']}'",
    require          => Docker::Image['puppetboard'],
  }
}
