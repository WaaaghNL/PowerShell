## With this script you can isntall and remove printers that are on your printserver, Set your AD domain and printserver in the Variables.
##
## How to use: Place this script in the root of new app and package the application as a intunewin file.
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -file SharedPrinterManagement.ps1 -Mode Install <printername>
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -file SharedPrinterManagement.ps1 -Mode Uninstall <printername>
##
## Create the folowing detection rules
## Rules format:     Manually configure detection rules
## Rule type:        Registry
## Keypath:          Computer\HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PrinterPorts
## Value name:       \\<PRINTSERVER>\<PRINTER>
## Detection method: Value Exitsts

## Error codes
## 0 Success
## 1707 Success
## 3010 Soft reboot
## 1641 Hard reboot
## 1618 Retry
##
## 9010 Printserver not set
## 9011 Printserver not reachable
##
## 9020 Printer does not exits on the printserver

Param(
	[Parameter(Mandatory=$true)]
	[ValidateSet("Install", "Uninstall")]
	[String]$Mode,

	[Parameter(Mandatory=$true)]
	[String]$PrinterName
)

## Variables
$PrintServerDNSName = "psei01.domain.example"

## Change printername to uppercase
$PrintServerDNSName = $PrintServerDNSName.ToLower()
$PrinterName = $PrinterName.ToUpper()

## What are we going to do? Install or Removing a printer
if ($Mode -eq "Install"){

    ## Check if printserver is reachable
    if (-not $PrintServerDNSName) {
        Write-Host "Please provide a target (IP address or domain name) to check."
        exit 9010
    }

    try {
        $result = Test-Connection -ComputerName $PrintServerDNSName -Count 2 -ErrorAction Stop
        Write-Host "The target $PrintServerDNSName is reachable."
    } catch {
        Write-Host "The target $PrintServerDNSName is not reachable. Error: $_.Exception.Message"
        exit 9011
    }

    ## Check if printer exists
    $printer = Get-Printer -ComputerName $PrintServerDNSName -Name $PrinterName -ErrorAction SilentlyContinue

    if ($printer -ne $null) {
        Write-Host "Printer '$PrinterName' exists on the print server '$PrintServerDNSName'."
    } else {
        Write-Host "Printer '$PrinterName' does not exist on the print server '$PrintServerDNSName'."
        exit 9020
    }
	
	## Install Printer
    Write-Host "Go and install the printer"
    Add-Printer -ConnectionName \\$PrintServerDNSName\$PrinterName
}
if ($Mode -eq "Uninstall"){
    ## check if printer exitsts in register
    Write-Host "Remove the printer"
    Remove-Printer -Name "\\$PrintServerDNSName\$PrinterName"
}