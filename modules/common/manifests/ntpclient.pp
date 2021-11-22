# Class: common::ntpclient
#
# Configures NTP on a node
class common::ntpclient {
  class {'::ntp':
    panic     => 0,
    tinker    => true,
    driftfile => '/var/lib/ntp/ntp.drift',
    servers   => ['0.pool.ntp.org','1.pool.ntp.org','2.pool.ntp.org','3.pool.ntp.org'],
    restrict  => [
      '-4 default kod notrap nomodify nopeer noquery',
      '-6 default kod notrap nomodify nopeer noquery',
      '127.0.0.1',
      '::1',
    ],
  }
}
