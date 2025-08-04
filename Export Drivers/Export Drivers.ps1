<#
.SYNOPSIS
    Exports all installed Windows drivers to a folder named after the device's serial number.

.DESCRIPTION
    This script performs the following actions:
    - Checks if it's running with Administrator privileges; if not, it restarts itself elevated.
    - Determines the script's starting location.
    - Retrieves the device's serial number using WMI.
    - Deletes any existing driver export folder with the same serial number.
    - Creates a new folder named "Drivers_<SerialNumber>" in the script's directory.
    - Exports all installed drivers to that folder using Export-WindowsDriver.

.NOTES
    - Requires Administrator privileges.
    - Compatible with Windows 10/11 and Server editions that support Export-WindowsDriver.
    - Must be run in an elevated PowerShell session or will auto-restart elevated.

.AUTHOR
    Ronald van Heugten
#>

# Ensure errors are shown
$ErrorActionPreference = "Stop"

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

# 2. Get script start location
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath

# 3. Get device serial number
try {
    $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber.Trim()
} catch {
    Write-Error "Failed to retrieve serial number: $_"
    exit 1
}

# 4. Prepare driver export folder
$driverExportDir = Join-Path -Path $scriptDir -ChildPath "Drivers_$serialNumber"

# If folder exists, delete it first
if (Test-Path -Path $driverExportDir) {
    try {
        Remove-Item -Path $driverExportDir -Recurse -Force
        Write-Host "Existing driver folder removed: $driverExportDir"
    } catch {
        Write-Error "Failed to remove existing folder: $_"
        exit 1
    }
}

# Create fresh folder
New-Item -Path $driverExportDir -ItemType Directory | Out-Null

# 5. Export installed drivers
try {
    Export-WindowsDriver -Online -Destination $driverExportDir
    Write-Host "Drivers successfully exported to: $driverExportDir"
} catch {
    Write-Error "Driver export failed: $_"
}
