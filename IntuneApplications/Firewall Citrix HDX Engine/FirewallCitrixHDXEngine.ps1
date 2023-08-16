## How to use:
## Place this script in the root of new app and package the application as a intunewin file.
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -file FirewallCitrixHDXEngine.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -file FirewallCitrixHDXEngine.ps1 -Mode Uninstall
##
## Create the folowing detection rules
## Rules format:     Manually configure detection rules
## Rule type:        Registry
## Keypath:          Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules
## Value name:       Citrix HDX Engine TCP
## Detection method: String comparison
## Operator:         Equals
## Value:            v2.30|Action=Allow|Active=TRUE|Dir=In|Protocol=6|App=C:\program files (x86)\citrix\ica client\wfica32.exe|Name=Citrix HDX Engine|Desc=Citrix HDX Engine|

## Rule type:        Registry
## Keypath:          Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules
## Value name:       Citrix HDX Engine UDP
## Detection method: String comparison
## Operator:         Equals
## Value:            v2.30|Action=Allow|Active=TRUE|Dir=In|Protocol=17|App=C:\program files (x86)\citrix\ica client\wfica32.exe|Name=Citrix HDX Engine|Desc=Citrix HDX Engine|

Param(
	[Parameter(Mandatory=$true, HelpMessage="Accepted values: Install, and Uninstall")]
	[ValidateSet("Install", "Uninstall")]
	[String]
	$Mode
)
 
if ($Mode -eq "Install"){
    ## Do Install Things
    ## New-NetFirewallRule -DisplayName "Citrix HDX Engine" -Direction Outbound -Program "C:\program files (x86)\citrix\ica client\wfica32.exe" -RemoteAddress LocalSubnet -Action Allow
    New-NetFirewallRule -DisplayName "Citrix HDX Engine TCP" -Name "Citrix HDX Engine TCP" -Description "Citrix HDX Engine" -Program "C:\program files (x86)\citrix\ica client\wfica32.exe" -Action Allow -Profile Any -Protocol TCP
    New-NetFirewallRule -DisplayName "Citrix HDX Engine UDP" -Name "Citrix HDX Engine UDP" -Description "Citrix HDX Engine" -Program "C:\program files (x86)\citrix\ica client\wfica32.exe" -Action Allow -Profile Any -Protocol UDP
}
if ($Mode -eq "Uninstall"){
    ## Do Uninstall Things
    Remove-NetFirewallRule -Name "Citrix HDX Engine TCP"
    Remove-NetFirewallRule -Name "Citrix HDX Engine UDP"
}