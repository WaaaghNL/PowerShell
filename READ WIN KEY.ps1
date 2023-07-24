# This script exports the installed license key in windows
# and saves it to a USB drive or on the desktop id the 
# USB drive is not setup

# Copyright 2023 Ronald van Heugten (WaaaghNL)

# Config
#$serialNumber = "0101fb92baf0e1b3d538"  # Replace this with the desired serial number
$serialNumber = "1234567890"  # Replace this with the desired serial number
$path = "\Windows Keys" # Replace this with the desired storage path

Write-Host "Export Windows Key Util" -ForegroundColor Green

# Code
$driveLetter = Get-DriveLetterBySerialNumber $serialNumber
if ($driveLetter) {
    Write-Host "Drive letter for serial number '$serialNumber': $driveLetter" -ForegroundColor Yellow

    If(!(test-path -PathType container $driveLetter$path)){
        Write-Host "Folder not found, Create: $driveLetter$path" -ForegroundColor Red
        New-Item -ItemType Directory -Path $driveLetter$path
    }
    $savePath = "$driveLetter$path"
}
else{
    Write-Host "No drive found with serial number '$serialNumber'." -ForegroundColor Red
    Write-Host "Please update the variable serialnumber with the correct drive!" -ForegroundColor Red
    Write-Host "Below you can find the serialnumbers for all connected drives.`r`n" -ForegroundColor Red
    Write-Host "We are saving to desktop for now.`r`n" -ForegroundColor Yellow


    Write-Host "Connected USB Drives." -ForegroundColor Green
    # Get the list of all disk drives
    $diskDrives = Get-WmiObject Win32_DiskDrive | Where-Object { $_.InterfaceType -eq 'USB' }

    # Loop through each USB drive and get the serial number
    foreach ($diskDrive in $diskDrives) {
        $serialNumber = $diskDrive.SerialNumber
        $model = $diskDrive.Model
        $caption = $diskDrive.Caption
        $size = ((($diskDrive.Size/1024)/1024)/1024)

        Write-Host "Drive: $caption"
        Write-Host "Model: $model"
        Write-Host "Size: $size GB"
        Write-Host "Serial Number: $serialNumber`r`n"
    }
    $savePath = "$env:USERPROFILE\Desktop" #Save to desktop
}

Write-Host "Getting serial information" -ForegroundColor Green

$licenseKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
$WinName = systeminfo | findstr /B /C:"OS Name"
$WinVersion = systeminfo | findstr /B /C:"OS Version"
$computerName = $env:COMPUTERNAME
Write-Output "Hostname: $computerName"
Write-Output $WinName
Write-Output $WinVersion
Write-Output "License: $licenseKey"

# Combine the variables into a single string
$outputString = "Hostname: $computerName`r`n$WinName`r`n$WinVersion`r`nLicense: $licenseKey"

# Save the combined string to a text file on the desktop
$outputString | Out-File "$savePath\$computerName.txt"
Write-Host "Saved to: $savePath\$computerName.txt" -ForegroundColor Green





function Get-DriveLetterBySerialNumber {
    param(
        [string]$SerialNumber
    )

    $query = "SELECT * FROM Win32_DiskDrive WHERE SerialNumber = '$SerialNumber'"
    $diskDrive = Get-WmiObject -Query $query

    if ($diskDrive) {
        $disk = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($diskDrive.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
        $partition = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($disk.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"
        
        if ($partition) {
            return $partition.DeviceID
        } else {
            Write-Host "No drive letter found for serial number '$SerialNumber'."
        }
    } else {
        Write-Host "No disk drive found with serial number '$SerialNumber'."
    }
}
