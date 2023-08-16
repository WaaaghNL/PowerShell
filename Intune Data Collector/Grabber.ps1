## ReadMe First
## 1 Make a fileshare on the network
## 1.1 Change the security so all users can write to it.
## 1.2 Change the Share Permissions to Everyone with full control

## 2 Create a new GPO
## Place Grabber.ps1 and Get-WindowsAutopilotInfo.ps1 in the fileshare. Change the permissions to readonly for everyone! This script runs under NT Authority\System!

## 3 Create a new GPO
## 3.1 Create in the GPO a Scheduled Task (Computer Configuration > Preferences > Control Panel Settings > Scheduled Tasks)
## 3.1.1 General
##  Set the Name
##    Set the Description
##    under Security Options
##      Set the useraccount to "NT Authority\System"
##      Set Run whether user is logged on or not
##      Set Run with highest Privilages
## 3.1.2 Triggers
##  Create a new trigger
##    Set begin the task: On a schedule
##    Set it Daily
##    Set a start time and date
##    Set recur every on 1 days
##    Set Repeat task every hour for a day
##    Set Stop all running tasks at end of repetitiion duration
##    Set Stop taks if it runs longer than 30 minutes
##    Set Enabled
## 3.1.3 Actions
##  Create a new Action
##    Set action to Start a program
##    Program/script: powershell
##    Aguments: -executionpolicy bypass -File <full pad to file>\Grabber.ps1
## 3.1.4 Settings
##  Set Allow task to be run on demand
## 3.2 Link the GPO to the computers OU

## 4 Let the data collect :)
## 4.1 This script creates 2 files on the share 
## 4.1.1 COMPUTERNAME-HWID.csv this contains the hardware id and serial for an import to intune
## 4.1.2 COMPUTERNAME.txt this contains the hardware ID, Serial, Computername, Installed windows version and windows Serial.

## 5 Combine CSV Files.ps1 This file combines all csv files to one file so it's easy to import in to intune

#Requires -RunAsAdministrator

$path = "\\SERVER\FILESHARE"

Write-Host $((get-date).ToString('yyyy-MM-dd_HH-mm-ss-fff')) -ForegroundColor Yellow

$computerName = $env:COMPUTERNAME

Write-Host 'Your computer is a laptop' -ForegroundColor Green

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Set-Location -Path $path

$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"

Write-Host 'Gather Intune Data' -ForegroundColor Yellow

powershell "$path\Get-WindowsAutopilotInfo.ps1" -OutputFile $computerName-HWID.csv

Write-Host "Gether System information" -ForegroundColor Yellow

$licenseKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
$WinName = systeminfo | findstr /B /C:"OS Name"
$WinVersion = systeminfo | findstr /B /C:"OS Version"
$computerSerial = (Get-WmiObject -class win32_bios).SerialNumber
Write-Host "Hostname: $computerName"
Write-Host $WinName
Write-Host $WinVersion
Write-Host "License: $licenseKey"
Write-Host "Machine SN: $computerSerial"

# Combine the variables into a single string
$outputString = "Hostname: $computerName;$WinName;$WinVersion;License: $licenseKey;Machine SN: $computerSerial"

# Save the combined string to a text file on the desktop
$outputString | Out-File "$path\$computerName.txt"
Write-Host "Saved to: $path\$computerName.txt" -ForegroundColor Green

Write-Host "Computer data written"

Write-Host "Script: Done"
exit