# Unload existing Graph module functions if they are already loaded
Get-Module Microsoft.Graph | ForEach-Object { Remove-Module $_.Name -Force }

# Install required modules if not already installed
$modules = @("MSOnline", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Install-Module $module -Force -AllowClobber
    }
}

# Import required modules
Import-Module MSOnline
Import-Module Microsoft.Graph.Users -ErrorAction Stop  # Import only the specific Graph submodule

# Connect to MSOnline if not already connected
if (-not (Get-MsolCompanyInformation -ErrorAction SilentlyContinue)) {
    Connect-MsolService
}

# Connect to Microsoft Graph with required permissions
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All"
}

# Main loop to allow returning to domain selection
do {
    # Get a list of unique domains from users
    $allUsers = Get-MsolUser
    $domains = $allUsers | Select-Object -ExpandProperty UserPrincipalName | ForEach-Object { $_.Split('@')[1] } | Sort-Object -Unique

    # Display the list of domains and prompt for selection
    Write-Host "Select a domain from the list below:`n"
    $index = 1
    foreach ($domain in $domains) {
        Write-Host "$index. $domain"
        $index++
    }
    Write-Host "$index. Exit"  # Add an option to exit

    $domainSelection = Read-Host "Enter the number corresponding to the domain"
    if ($domainSelection -eq $index.ToString()) {
        Write-Host "Exiting..."
        break
    }
    elseif ($domainSelection -match '^\d+$' -and [int]$domainSelection -gt 0 -and [int]$domainSelection -le $domains.Count) {
        $selectedDomain = $domains[([int]$domainSelection - 1)]
        Write-Host "You selected domain: $selectedDomain"
    } else {
        Write-Host "Invalid domain selection. Returning to domain selection..."
        continue
    }

    # Filter users by selected domain and sort them alphanumerically
    $users = $allUsers | Where-Object { $_.UserPrincipalName -like "*@$selectedDomain" } | 
             Select-Object -ExpandProperty UserPrincipalName |
             Sort-Object

    # Display a menu for selection of the user UPN
    $index = 1
    Write-Host "`nSelect a user UPN from the list below:`n"
    foreach ($user in $users) {
        Write-Host "$index. $user"
        $index++
    }

    # Prompt for user selection
    $userSelection = Read-Host "Enter the number corresponding to the user UPN"
    if ($userSelection -match '^\d+$' -and [int]$userSelection -gt 0 -and [int]$userSelection -le $users.Count) {
        $selectedUPN = $users[([int]$userSelection - 1)]
        Write-Host "You selected user: $selectedUPN"

        # Remove the user's photo
        Remove-MgUserPhoto -UserId $selectedUPN
        Write-Host "Photo for user $selectedUPN has been removed."
    } else {
        Write-Host "Invalid user selection. Returning to domain selection..."
    }

} while ($true)  # End of main loop

# Disconnect from Microsoft services
Disconnect-ExchangeOnline -Confirm:$false