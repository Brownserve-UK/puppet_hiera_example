# @summary If declared this will install and configure any common base settings, eg ensure Puppet agent is running.
# 
# @param manage_puppet
#   If set will manage the puppet agent.
# @param manage_users
#   If set will manage the local users.
class common
(
  Boolean $manage_puppet = true,
  Boolean $manage_users = true,
)
{
  # Create our standard local users (except on nodes where we don't want to)
  if $manage_users
  {
      contain common::users
  }
  if ($::osfamily == 'windows')
  {
    include common::windows
  }
  else
  {
    # Assume if we've not got Windows we must be Linux
    include common::linux
  }
  if $manage_puppet {
    contain common::puppet_agent
  }
}
