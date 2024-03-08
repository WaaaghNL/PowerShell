## Tips:
### Run Start-Process with -Wait -NoNewWindow -PassThru https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7.3
##
##
## How to use:
## 1. Download the version of dotNet that you need from Microsoft https://dotnet.microsoft.com/en-us/download/dotnet
## 2. Place the download in the same folder as app.ps1
## 3. Edit the name of the downloaded file in the code below
## 4. Package the application as a intunewin file.
## 5. Deploy the app in intune
## 
## Install command:   powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -file app.ps1 -Mode Install
## Uninstall command: powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -file app.ps1 -Mode Uninstall
##
## Create the folowing detection rule
## Rules format:     Manually configure detection rules
## Rule type:        File
## Path:             C:\Program Files\Application
## File or folder:   App.exe
## Detection method: File or folder exists

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
    dotnet-sdk-x.x.x-win-x64.exe /install /quiet /norestart
}
 
if ($Mode -eq "Uninstall"){
    ## Do Uninstall Things
    dotnet-sdk-x.x.x-win-x64.exe /uninstall /quiet /norestart
}

##
## Functions
## Love them, Hate them!
##
