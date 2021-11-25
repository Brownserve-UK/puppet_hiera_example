# Class: common::windows
#
#
class common::windows
()
{
  # Make sure chocolatey is configured on Windows systems and set as default package provider - if this doesn't work, revist.
  # n.b. if we do change this then we'll need to set chocolatey as the default package provider for common::puppet_agent
  include chocolatey
  Package { provider => chocolatey, }
  # Install our standard apps
  $standard_apps = ['7zip']
  package { $standard_apps:
    ensure => 'present',
  }

  # ensure Powershell is defaut on Windows Server Core
  if ($::windows_installation_type == 'Server Core')
  {
    registry::value {
      'Shell':
        key  => 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon',
        data => 'PowerShell.exe -NoExit',
    }
  }
}
