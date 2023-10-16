## This script allows end users to install printer drivers without using administrator credentials
##
## How to use: Place this script in the root of new app and package the application as a intunewin file.
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -file AllowInstallingPrinterDrivers.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -file AllowInstallingPrinterDrivers.ps1 -Mode Uninstall
##
## Create the folowing detection rules
## Rules format:     Manually configure detection rules
## Rule type:        Registry
## Keypath:          Computer\HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint
## Value name:       RestrictDriverInstallationToAdministrators
## Detection method: Integer comparison
## Operator:         Equals
## Value:            0

Param(
	[Parameter(Mandatory=$true)]
	[ValidateSet("Install", "Uninstall")]
	[String]
	$Mode
)

## Path
$path = 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint'  

if ($Mode -eq "Install"){
    if (Test-Path -Path $path) {
        Set-ItemProperty -Path $path -Name "RestrictDriverInstallationToAdministrators" -Value 0 -Force -ea SilentlyContinue
    }
    else{
        New-item -Path $path  
        New-ItemProperty -Path $path -Name "RestrictDriverInstallationToAdministrators" -Value 0 -PropertyType DWord -Force -ea SilentlyContinue
    }
}
 
if ($Mode -eq "Uninstall"){
	if (Test-Path -Path $path) {
        Remove-Item -Path $path -Recurse
    }
}