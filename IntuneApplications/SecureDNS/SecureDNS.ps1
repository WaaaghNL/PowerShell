## How to use:
## Place this script in the root of the aquired zip file from SecTec (there shoud be two folders named install and uninstall) and package the application as a intunewin file.
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -file SecureDNS.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -file SecureDNS.ps1 -Mode Uninstall
##
## Create the folowing detection rule
## Rules format:     Manually configure detection rules
## Rule ype:         Registry
## Keypath:          Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags
## Value name:       client
## Detection method: String comparison
## Operator:         Equals
## Value:            Your licence key (You can find this in install/install.bat on the top of the file. The row starts with "set LicenseKey=" copy the values between the quotes)

Param(
	[Parameter(Mandatory=$true, HelpMessage="Accepted values: Install, and Uninstall")]
	[ValidateSet("Install", "Uninstall")]
	[String[]]
	$Mode
)

## Path to WireGuard Shortcut in start menu
$WireGuardShortcut = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\WireGuard.lnk"

## Test if WireGuard Shortcut already exists
$WireGuardShortcutExists = Test-Path -Path $WireGuardShortcut
 
if ($Mode -eq "Install"){
    Start-Process .\install\install.bat

    ## Remove WireGuard from start menu if it exists and did not exist before    
    if (Test-Path -Path $WireGuardShortcut -and $WireGuardShortcutExists -eq "False") {
        Remove-Item -Path $WireGuardShortcut
    }
}
 
if ($Mode -eq "Uninstall"){
	Start-Process .\uninstall\uninstall.bat
}
