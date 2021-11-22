# Class: puppetserver::firewall
#
# Configures the firewall on the puppet server to allow expected services.
class puppetserver::firewall {
  firewall { '001 accept SSH':
      proto  => 'tcp',
      dport  => 22,
      action => accept,
  }
  -> firewall { '002 allow 8081 (PuppetDB)':
      proto  => 'tcp',
      dport  => 8081,
      action => accept,
  }
  -> firewall { '003 allow 8140 (Puppet Agent Incoming)':
      proto  => 'tcp',
      dport  => 8140,
      action => accept,
  }
  -> firewall { '999 drop all':
    proto  => 'all',
    action => 'drop',
    before => undef,
  }
}
