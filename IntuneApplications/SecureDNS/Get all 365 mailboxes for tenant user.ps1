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
Connect-ExchangeOnline -ShowProgress $true

# Specify the user whose mailbox access you want to check
$emailPattern = "^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$"
$maxEmailLength = 254

do {
    $targetUser = Read-Host -Prompt "Enter the UserPrincipalName (email) of the user"
    if ($targetUser.Length -le $maxEmailLength -and $targetUser -match $emailPattern) {
        Write-Output "The input is a valid email address."
        $isValid = $true
    } else {
        Write-Output "The input is not a valid email address. Please try again."
        $isValid = $false
    }
} while (-not $isValid)

# Retrieve all mailboxes and filter where the user has FullAccess permissions
$allMailboxes = Get-Mailbox -ResultSize Unlimited
$mailboxesWithAccess = @()

foreach ($mailbox in $allMailboxes) {
    $permissions = Get-MailboxPermission -Identity $mailbox.PrimarySmtpAddress
    foreach ($permission in $permissions) {
        if ($permission.User -like $targetUser) {
            $mailboxesWithAccess += $mailbox.PrimarySmtpAddress
        }
    }
}

Write-Host -ForegroundColor Yellow "`nUser $targetUser has access to the following mailboxes:"

# Output the mailboxes
if ($mailboxesWithAccess.Count -gt 0) {
    Write-Host "`nUser $targetUser has access to the following mailboxes:"
    $mailboxesWithAccess | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "`nUser $targetUser does not have access to any mailboxes."
}

# Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false

#prevent closing of windows after output
pause
