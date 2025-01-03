# Install required modules if not already installed
$modules = @("ExchangeOnlineManagement", "MSOnline")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Install-Module $module -Force -AllowClobber
    }
}

# Import required modules
Import-Module ExchangeOnlineManagement
Import-Module MSOnline

# Connect to Exchange Online
Connect-ExchangeOnline



# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false
