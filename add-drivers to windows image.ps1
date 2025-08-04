# 1. Check if running as Administrator
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Restarting script with administrator privileges..."
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

## Export install.esd to install.wim and back again
## https://woshub.com/integrate-drivers-to-windows-install-media/
## https://www.zdnet.com/article/windows-10-installer-files-too-big-for-usb-flash-drive-heres-the-fix/


# Check if Mount folder exists

$mount = "C:\Mount"
$drivers = ".\Drivers"
$bootfile = "sources\boot.wim";
$installfile = "sources\install.wim";

#move to scriptfile location
Set-Location -Path $PSScriptRoot
cd $PSScriptRoot
Write-host "My directory is $PSScriptRoot" -ForegroundColor Yellow

If(!(test-path -PathType container $mount))
{
      New-Item -ItemType Directory -Path $mount
}
If(!(test-path -PathType container $drivers))
{
      New-Item -ItemType Directory -Path $drivers
}
if (!(Test-Path $bootfile) -and !(Test-Path $installfile)) {
  Write-Warning "$bootfile and/or $installfile is absent"
  exit
}

Write-Host "Adding drivers to $bootfile" -ForegroundColor Green



Write-Host "Mounting $bootfile on Index:1" -ForegroundColor Yellow
Mount-WindowsImage -Path $mount -ImagePath $bootfile -Index 1

Write-Host "Adding drivers from $drivers to $bootfile on Index:1" -ForegroundColor Yellow
Write-Host "Yup this takes some time............." -ForegroundColor Yellow
Add-WindowsDriver -Path $mount -Driver $drivers -Recurse

Write-Host "Unmounting $bootfile with Index:1" -ForegroundColor Yellow
Dismount-WindowsImage -Path $mount �Save

Write-Host "Mounting $bootfile on Index:2" -ForegroundColor Yellow
Mount-WindowsImage -Path $mount -ImagePath $bootfile -Index 2

Write-Host "Adding drivers from $drivers to $bootfile on Index:2" -ForegroundColor Yellow
Write-Host "Yup this takes some time............." -ForegroundColor Yellow
Add-WindowsDriver -Path $mount -Driver $drivers -Recurse

Write-Host "Unmounting $bootfile with Index:2" -ForegroundColor Yellow
Dismount-WindowsImage -Path $mount �Save



Write-Host "Adding drivers to $installfile" -ForegroundColor Green

Write-Host "Mounting $installfile on Index:1" -ForegroundColor Yellow
Mount-WindowsImage -Path $mount -ImagePath $installfile -Index 1

Write-Host "Adding drivers from $drivers to $installfile on Index:1" -ForegroundColor Yellow
Write-Host "Yup this takes some time............." -ForegroundColor Yellow
Add-WindowsDriver -Path $mount -Driver $drivers -Recurse

Write-Host "Unmounting $installfile with Index:1" -ForegroundColor Yellow
Dismount-WindowsImage -Path $mount �Save

Write-Host "Cutting $installfile in pieces so it fits on a FAT32 USB" -ForegroundColor Yellow
Dism /Split-Image /ImageFile:$installfile /SWMFile:install.swm /FileSize:3800

Write-Host "Remove the install.esd from your USB drive" -ForegroundColor Green
Write-Host "You can now replace $bootfile and add the install.swm and installX.swm files to your windows USB drive" -ForegroundColor Green