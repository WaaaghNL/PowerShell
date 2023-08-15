## How to use:
## * Download the Steam installer and place it in the in the same folder as this file.
## * Package the application as a intunewin file.
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -file Steam.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -file Steam.ps1 -Mode Uninstall
##
## Create the folowing detection rule
## Rules format:     Manually configure detection rules
## Rule type:        File
## Path:             C:\Program Files (x86)\Steam\
## File or folder:   steam.exe
## Detection method: File or folder exists

Param(
	[Parameter(Mandatory=$true, HelpMessage="Accepted values: Install, and Uninstall")][ValidateSet("Install", "Uninstall")][String] $Mode
)
 
if ($Mode -eq "Install"){
    Start-Process SteamSetup.exe /S
}
 
if ($Mode -eq "Uninstall"){
    Start-Process "${env:ProgramFiles(x86)}\Steam\uninstall.exe" /S
}
