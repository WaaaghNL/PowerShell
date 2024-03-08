## Tips:
### Run Start-Process with -Wait -NoNewWindow -PassThru https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.3
##
##
## How to use:
## Place this script in the root of new app and package the application as a intunewin file.
## 
## Install command:   powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -file app.ps1 -Mode Install
## Uninstall command: powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -file app.ps1 -Mode Uninstall
##
## Create the folowing detection rule (file)
## Rules format:     Manually configure detection rules
## Rule type:        File
## Path:             C:\Program Files\Application
## File or folder:   App.exe
## Detection method: File or folder exists
##
## Create the folowing detection rule (register)
## Rules format:     Manually configure detection rules
## Rule type:         Registry
## Keypath:          keypath
## Value name:       Version
## Detection method: String comparison
## Operator:         Equals
## Value:            Version number like 6.0.27

##
## Parameters, Sorry you can't create code above this. Blame Microsoft!
##
Param(
	[Parameter(Mandatory=$true, HelpMessage="Accepted values: Install, and Uninstall")]
	[ValidateSet("Install", "Uninstall")]
	[String] $Mode
)

##
## Config
## Place here your config variables
##


##
## Script
## Let it run!
## 
if ($Mode -eq "Install"){
    ## Do Install Things
}
 
if ($Mode -eq "Uninstall"){
    ## Do Uninstall Things
}

##
## Functions
## FLove them, Hate them!
##
