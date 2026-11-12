## With this script you can install and remove fonts.
##
## How to use: Place this script in the root of new app and package the application as a intunewin file.
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -file Barcode.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -file Barcode.ps1 -Mode Uninstall
##

## Error codes
## 0 Success
## 1707 Success
## 3010 Soft reboot
## 1641 Hard reboot
## 1618 Retry


Param(
	[Parameter(Mandatory=$true)]
	[ValidateSet("Install", "Uninstall")]
	[String]$Mode
)

## What are we going to do? Install or Removing fonts
if ($Mode -eq "Install"){
    Write-Host "Installing the fonts"

    $AllFonts = Get-ChildItem -Path ".\fonts\*.ttf"
    foreach($FontFile in $AllFonts){
        try{
            Copy-Item -Path ".\fonts\$($FontFile.Name)" -Destination "$env:windir\Fonts" -Force -PassThru -ErrorAction Stop
        }catch{
            Write-Host $_
        }
    }
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c reg.exe import `".\Fonts_Install.reg`"" -Wait -passthru

}
if ($Mode -eq "Uninstall"){
    Write-Host "Removing the fonts"

    $AllFonts = Get-ChildItem -Path ".\fonts\*.ttf"
    foreach ($FontFile in $AllFonts) {
        Remove-Item ("$env:windir\fonts\"+$fontfile.name) -Force
    }
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c reg.exe import `".\Fonts_Uninstall.reg`"" -Wait -passthru
}