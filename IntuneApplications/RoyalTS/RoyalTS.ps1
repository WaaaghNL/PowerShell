## How to use:
## Place this script in the root of new app and package the application as a intunewin file.
##
## Add your License information to the code4ward.RoyalTS.Lic.V5.xml file
## Add your own version of royal ts
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -file RoyalTS.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -file RoyalTS.ps1 -Mode Uninstall
##
## Create the folowing detection rule
## Rules format:     Manually configure detection rules
## Rule type:        File
## Path:             C:\Program Files (x86)\Royal TS V5
## File or folder:   RoyalTS.exe
## Detection method: File or folder exists

Param(
	[Parameter(Mandatory=$true, HelpMessage="Accepted values: Install, and Uninstall")]
	[ValidateSet("Install", "Uninstall")]
	[String]
	$Mode
)
 
if ($Mode -eq "Install"){
    ## Do Install Things
	
	## Install Royal TS	
	Write-Host "Installing Royal TS"
	msiexec /i .\RoyalTSInstaller_5.04.60415.0.msi /qn
	
	##Wait untill msiexec is done	
	While (!(Test-Path "C:\Program Files (x86)\Royal TS V5\" -ErrorAction SilentlyContinue))
	{
		Write-Host "Waiting for the installation to create the Royal TS folder in Program Files"
		Start-Sleep -Seconds 5
	}
	
	## Install License
	Write-Host "Installing Royal TS License"
	Copy-Item -Path ".\code4ward.RoyalTS.Lic.V5.xml" -Destination "C:\Program Files (x86)\Royal TS V5\code4ward.RoyalTS.Lic.V5.xml" -Recurse
	
	Write-Host "Done"
}
 
if ($Mode -eq "Uninstall"){
    ## Do Uninstall Things
	## Start-Process "C:\Program Files\Logitech\LogiOptions\uninstaller.exe" /S
	
	## Remove License
	Write-Host "Remove Royal TS License"
	Remove-Item "C:\Program Files (x86)\Royal TS V5\code4ward.RoyalTS.Lic.V5.xml"
	
	## Run Uninstall
	Write-Host "Uninstall Royal TS"
	msiexec /x "{96FD33BF-A8E3-4E1C-93AF-8CD5DD2817EC}" /qn
	
	While ((Test-Path "C:\Program Files (x86)\Royal TS V5\" -ErrorAction SilentlyContinue))
	{
		Write-Host "Waiting for the uninstaller to remove the Royal TS folder in Program Files"
		Start-Sleep -Seconds 2
	}
	
	Write-Host "Done"
}