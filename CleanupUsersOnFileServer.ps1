# Array of folders that you want to clean up
$directories = @("\\fileserver01\c$\Profiles", "c:\UserProfiles")

# what subfolder
$RemovedFolderName = "@Directories of removed users"

# Zoek alle sAMAccountName hebbende objecten in AD
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(objectClass=user)"
$searcher.PropertiesToLoad.Add("sAMAccountName") | Out-Null

# Haal alle gebruikersnamen op van de beschikbare gebruikers.
$adUsers = @()
$results = $searcher.FindAll()
foreach ($result in $results) {
    $adUsers += $result.Properties["sAMAccountName"]
}

foreach ($directory in $directories) {
    # Kijk of de map benaderbaar is
    if (Test-Path -Path $directory) {
        # Maak de map aan voor oude profielen als deze niet bestaat
        $nonMatchingDir = Join-Path -Path $directory -ChildPath $RemovedFolderName
        if (-not (Test-Path -Path $nonMatchingDir)) {
            New-Item -Path $nonMatchingDir -ItemType Directory
        }

        # Maak een lijst van alle mapnamen in de array map
        $items = Get-ChildItem -Path $directory -Directory

        foreach ($item in $items) {
            # Pak alleen de map naam
            $itemName = $item.Name

            # Sla de map voor oude gebruikers over
            if ($itemName -eq $RemovedFolderName) {
                continue
            }

            # Kijk of de map naam voorkomt in de ad gebruikers username array
            if (-not ($adUsers -contains $itemName)) {
                # Zo niet verplaats de map naar de oude gebruikers folder zodat deze ter beoordeling beschikbaar is
                $destination = Join-Path -Path $nonMatchingDir -ChildPath $itemName
                Move-Item -Path $item.FullName -Destination $destination -Force
            }
        }
    } else {
        Write-Host "Geen toegang tot map $directory ."
    }
}