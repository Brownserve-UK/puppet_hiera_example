#@summary creates a user on Windows/Linux host
define common::user(
  Optional[String]$password = undef,
  Optional[Array]$ssh_keys = undef,
  Optional[Array]$windows_groups = undef,
  Optional[Array]$linux_groups = undef,
  Optional[Boolean]$administrator=false,
  Optional[String]$bash_profile_content = undef,
  $ensure
)
{
  # resources
  if (!$password) and (!$ssh_keys)
  {
    fail('No password or SSH key configured')
  }
  if ($::osfamily == 'windows')
  {
    if (!$password)
    {
      fail('Windows users must have a password')
    }
    if ($administrator == true)
    {
      if $windows_groups
      {
        $groups = ['Administrators'] + $windows_groups
      }
      else
      {
        $groups = ['Administrators']
      }
    }
    else
    {
      $groups = $windows_groups
    }
    user { $name:
      ensure   => $ensure,
      password => Sensitive($password),
      groups   => $groups
    }
  }
  else
  {
    if ($administrator == true)
    {
      if $linux_groups
      {
        $groups = ['wheel'] + $linux_groups
      }
      else
      {
        $groups = ['wheel']
      }
    }
    if $password
    {
      $password_to_set = pw_hash($password, 'SHA-512', 'totally/random.salt')
    }
    else
    {
      $password_to_set = '!!'
    }
    $groups.each | $group| {
      ensure_resource('group',$group, {'ensure' => 'present'}) # creates a group if it doesn't already exist
    }
    accounts::user { $name:
      ensure                   => $ensure,
      groups                   => $groups,
      create_group             => true,
      group                    => $name,
      ignore_password_if_empty => true,
      sshkeys                  => $ssh_keys,
      password                 => $password_to_set,
      purge_sshkeys            => true,
      bash_profile_content     => $bash_profile_content,
    }
  }
}
