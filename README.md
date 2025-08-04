# PowerShell
Random Powershell Scripts, if you find something you like please take it with you!

## Intune Data Collector

## Intune Roll Out

## IntuneApplications
Install scripts for Intune

## Snippets

## Add-drivers to windows image
Easy script to put the drivers into a windows install

## CleanupUsersOnFileServer
Cleans up folders from the file server when a user is removed from Active Directory. It won't delete them just moves them to a easy to see subfolder

## Export Drivers.ps1
Exports the drivers from the machine it's running on and saves it to Drivers_Serialnumber in the same location as the script is running from.

## Find MSI Uninstall ID.ps1
Finds Uninsall ID's for MSI installs

## READ WIN KEY.ps1
Reads the windows 10 license key and saves it to a USB drive (if setup) else it will be saved to the desktop.

Config: In the top of the script there are 2 variables that you can use to change it's function.

* ```$serialnumber``` Here you can save the USB drive where you want to save the output to. Nice i you need to do a lot of computers
* ```$path``` Here you can set the output location of the script on the USB drive. 

NOTE! When the ```$serialnumber``` is not set correct it will save the file to the desktop and show all connected usb drives with the serial numbers