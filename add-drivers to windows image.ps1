<#
.SYNOPSIS
    Injecteert drivers in Windows 11 installer bestanden (boot.wim en install.wim/swm).

.DESCRIPTION
    Dit script verifieert administrator rechten en herstart zichzelf indien nodig. Het controleert PowerShell versie compatibiliteit,
    zorgt ervoor dat er minimaal 25GB vrije schijfruimte is, creëert benodigde mappen, en presenteert een interactief menu
    voor het injecteren van drivers. Het script handelt automatisch gesplitste SWM bestanden af door ze samen te voegen
    tot een WIM bestand, drivers te injecteren, en ze weer terug te splitsen.

.AUTHOR
    Ronald van Heugten

.CREATED
    2025-08-06

.LASTMODIFIED
    2025-08-07

.VERSION
    1.2.0

.CHANGELOG
    1.2.0 - SWM bestand ondersteuning toegevoegd voor install.wim > 3.8GB
    1.1.0 - Verbeterde foutafhandeling, consistentie en functionaliteit toegevoegd
    1.0.0 - Initiële versie

.PARAMETER DryRun
    Simuleert acties zonder daadwerkelijke wijzigingen door te voeren.

.EXAMPLE
    .\inject-drivers.ps1 -Verbose
    .\inject-drivers.ps1 -DryRun
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [switch]$DryRun
)

# Global Variables
$LogFile = "$([Environment]::GetFolderPath('Desktop'))\inject-drivers.log"
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $ScriptPath
$RequiredFolders = @(
    "sources",
    "sources-export", 
    "drivers-boot",
    "drivers-install",
    "mount-boot",
    "mount-install",
    "temp-wim"
)

# Initialiseer logging
if (-not (Test-Path $LogFile)) {
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARNING" { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        default { Write-Verbose $entry }
    }
}

function Check-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Log "Administrator check: $isAdmin"
    return $isAdmin
}

function Restart-AsAdmin {
    Write-Log "Script wordt herstart als administrator..."
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    if ($DryRun) {
        $arguments += " -DryRun"
    }
    if ($VerbosePreference -eq "Continue") {
        $arguments += " -Verbose"
    }
    
    if ($DryRun) {
        Write-Log "DryRun: Zou script herstarten als administrator met argumenten: $arguments"
        return
    }
    
    try {
        Start-Process powershell -Verb RunAs -ArgumentList $arguments
        Write-Log "Script herstart als administrator"
        exit
    } catch {
        Write-Log "Fout bij herstarten als administrator: $_" "ERROR"
        Read-Host "Druk Enter om door te gaan..."
        exit 1
    }
}

function Check-PowerShellVersion {
    $minVersion = 5.1
    $currentVersion = $PSVersionTable.PSVersion.Major + ($PSVersionTable.PSVersion.Minor / 10)
    Write-Log "Huidige PowerShell versie: $currentVersion"
    
    if ($currentVersion -lt $minVersion) {
        Write-Log "Waarschuwing: PowerShell versie is onder $minVersion. Sommige functies werken mogelijk niet." "WARNING"
        return $false
    }
    return $true
}

function Check-DiskSpace {
    try {
        $drive = Get-PSDrive -Name ($ScriptDir.Substring(0,1))
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        Write-Log "Vrije schijfruimte op $($drive.Name): $freeGB GB"
        
        if ($freeGB -lt 25) {
            Write-Log "Onvoldoende schijfruimte. Minimaal 25GB vereist." "ERROR"
            return $false
        }
        return $true
    } catch {
        Write-Log "Fout bij controleren schijfruimte: $_" "ERROR"
        return $false
    }
}

function Create-Folders {
    $success = $true
    foreach ($folder in $RequiredFolders) {
        $fullPath = Join-Path -Path $ScriptDir -ChildPath $folder
        
        if (-not (Test-Path $fullPath)) {
            if ($DryRun) {
                Write-Log "DryRun: Zou map $fullPath aanmaken"
            } else {
                try {
                    New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                    Write-Log "Map aangemaakt: $fullPath" "SUCCESS"
                } catch {
                    Write-Log "Fout bij aanmaken map $fullPath $_" "ERROR"
                    $success = $false
                }
            }
        } else {
            Write-Log "Map bestaat al: $fullPath"
        }
    }
    return $success
}

function Check-DismAvailability {
    try {
        $dismInfo = dism /?
        if ($LASTEXITCODE -eq 0) {
            Write-Log "DISM is beschikbaar"
            return $true
        } else {
            Write-Log "DISM is niet beschikbaar of werkt niet correct" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Fout bij controleren DISM beschikbaarheid: $_" "ERROR"
        return $false
    }
}

function Cleanup-MountPoint {
    param (
        [string]$MountPath
    )
    
    if (-not (Test-Path $MountPath)) {
        return $true
    }
    
    $mountContents = Get-ChildItem -Path $MountPath -ErrorAction SilentlyContinue
    
    if ($mountContents.Count -gt 0) {
        Write-Log "Mount map is niet leeg. Opruimen..."
        
        # Probeer eerst netjes te unmounten
        try {
            if ($DryRun) {
                Write-Log "DryRun: Zou mount point $MountPath unmounten"
            } else {
                dism /Unmount-Image /MountDir:$MountPath /Discard | Out-Null
                Write-Log "Mount point succesvol unmount"
            }
        } catch {
            Write-Log "Waarschuwing: Kon niet netjes unmounten: $_" "WARNING"
        }
        
        # Ruim bestanden op
        if ($DryRun) {
            Write-Log "DryRun: Zou bestanden in $MountPath opruimen"
        } else {
            try {
                Remove-Item -Path "$MountPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Mount map opgeruimd" "SUCCESS"
            } catch {
                Write-Log "Fout bij opruimen mount map: $_" "ERROR"
                return $false
            }
        }
    }
    return $true
}

function Test-WimFile {
    param (
        [string]$WimPath
    )
    
    if (-not (Test-Path $WimPath)) {
        return $false
    }
    
    try {
        if ($DryRun) {
            Write-Log "DryRun: Zou WIM bestand $WimPath controleren"
            return $true
        }
        
        $wimInfo = dism /Get-WimInfo /WimFile:$WimPath
        return $LASTEXITCODE -eq 0
    } catch {
        Write-Log "Fout bij controleren WIM bestand: $_" "ERROR"
        return $false
    }
}

function Find-InstallWimOrSwm {
    param (
        [string]$SourcesPath
    )
    
    $installWim = Join-Path -Path $SourcesPath -ChildPath "install.wim"
    $installSwm = Join-Path -Path $SourcesPath -ChildPath "install.swm"
    
    if (Test-Path $installWim) {
        Write-Log "install.wim gevonden"
        return @{
            Type = "WIM"
            MainFile = $installWim
            SplitFiles = @()
        }
    } elseif (Test-Path $installSwm) {
        Write-Log "install.swm gevonden, zoeken naar gesplitste bestanden..."
        
        # Zoek alle install*.swm bestanden
        $swmFiles = Get-ChildItem -Path $SourcesPath -Name "install*.swm" | Sort-Object
        if ($swmFiles.Count -gt 0) {
            Write-Log "Gevonden SWM bestanden: $($swmFiles -join ', ')"
            return @{
                Type = "SWM"
                MainFile = $installSwm
                SplitFiles = $swmFiles | ForEach-Object { Join-Path -Path $SourcesPath -ChildPath $_ }
            }
        } else {
            Write-Log "Geen install.swm bestanden gevonden" "ERROR"
            return $null
        }
    } else {
        Write-Log "Geen install.wim of install.swm gevonden" "ERROR"
        return $null
    }
}

function Merge-SwmToWim {
    param (
        [array]$SwmFiles,
        [string]$OutputWimPath
    )
    
    Write-Log "Samenvoegen SWM bestanden naar WIM..."
    
    if ($DryRun) {
        Write-Log "DryRun: Zou SWM bestanden samenvoegen naar $OutputWimPath"
        return $true
    }
    
    try {
        # Zorg ervoor dat output path niet bestaat
        if (Test-Path $OutputWimPath) {
            Remove-Item $OutputWimPath -Force
            Write-Log "Oude output WIM verwijderd"
        }
        
        $mainSwm = $SwmFiles[0]
        Write-Log "Hoofdbestand: $mainSwm"
        Write-Log "Alle bestanden: $($SwmFiles -join ', ')"
        
        # Methode 1: Gebruik dism /Get-WimInfo om eerst te testen wat er in zit
        Write-Log "Controleren SWM bestand integriteit..."
        $wimInfo = dism /Get-WimInfo /WimFile:`"$mainSwm`"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "SWM hoofdbestand is niet leesbaar of beschadigd" "ERROR"
            return $false
        }
        
        # Parse aantal images
        $imageCount = 0
        $wimInfo | ForEach-Object {
            if ($_ -match "Index\s*:\s*(\d+)") {
                $currentIndex = [int]$matches[1]
                if ($currentIndex -gt $imageCount) {
                    $imageCount = $currentIndex
                }
            }
        }
        Write-Log "Gevonden $imageCount images in SWM bestand"
        
        if ($imageCount -eq 0) {
            Write-Log "Geen geldige images gevonden in SWM bestand" "ERROR"
            return $false
        }
        
        # Methode 1: Export per image index (meest betrouwbaar voor SWM)
        Write-Log "Methode 1: Export per image index..."
        $success = $true
        
        for ($i = 1; $i -le $imageCount; $i++) {
            Write-Log "Exporteren image index $i..."
            
            if ($i -eq 1) {
                # Eerste image: creëer nieuw WIM bestand
                $result = dism /Export-Image /SourceImageFile:`"$mainSwm`" /SourceIndex:$i /DestinationImageFile:`"$OutputWimPath`" /Compress:max
            } else {
                # Volgende images: voeg toe aan bestaand WIM
                $result = dism /Export-Image /SourceImageFile:`"$mainSwm`" /SourceIndex:$i /DestinationImageFile:`"$OutputWimPath`" /Compress:max
            }
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Fout bij exporteren image index $i. Exit code: $LASTEXITCODE" "WARNING"
                Write-Log "DISM output voor index $i $result" "WARNING"
                $success = $false
                break
            } else {
                Write-Log "Image index $i succesvol geëxporteerd" "SUCCESS"
            }
        }
        
        if (-not $success) {
            Write-Log "Per-index export mislukt, proberen bulk export..." "WARNING"
            
            # Verwijder gefaalde poging
            if (Test-Path $OutputWimPath) {
                Remove-Item $OutputWimPath -Force
            }
            
            # Methode 2: Bulk export alle images
            Write-Log "Methode 2: Bulk export alle images..."
            $result = dism /Export-Image /SourceImageFile:`"$mainSwm`" /SourceIndex:* /DestinationImageFile:`"$OutputWimPath`" /Compress:max
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Bulk export mislukt, proberen eenvoudige kopie..." "WARNING"
                
                # Methode 3: Direct copy (laatste redmiddel)
                Write-Log "Methode 3: Direct copy als laatste redmiddel..."
                Copy-Item -Path $mainSwm -Destination $OutputWimPath -Force
                
                # Test of het gekopieerde bestand werkt
                $testResult = dism /Get-WimInfo /WimFile:`"$OutputWimPath`"
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Alle SWM merge methodes gefaald" "ERROR"
                    return $false
                }
            }
        }
        
        # Valideer het resultaat
        Write-Log "Valideren samengevoegd WIM bestand..."
        $finalTest = dism /Get-WimInfo /WimFile:`"$OutputWimPath`"
        if ($LASTEXITCODE -eq 0) {
            # Toon info over het resultaat
            $finalInfo = $finalTest | Where-Object { $_ -match "Index|Name" }
            Write-Log "WIM validatie succesvol. Inhoud:"
            $finalInfo | ForEach-Object { Write-Log "  $_" }
            
            Write-Log "SWM bestanden succesvol samengevoegd naar WIM" "SUCCESS"
            return $true
        } else {
            Write-Log "Finaal WIM bestand is niet geldig" "ERROR"
            Write-Log "DISM validatie output: $finalTest" "ERROR"
            return $false
        }
        
    } catch {
        Write-Log "Exception bij samenvoegen SWM bestanden: $_" "ERROR"
        return $false
    }
}

function Split-WimToSwm {
    param (
        [string]$WimPath,
        [string]$OutputPath,
        [string]$BaseName = "install"
    )
    
    Write-Log "Splitsen WIM naar SWM bestanden..."
    
    if ($DryRun) {
        Write-Log "DryRun: Zou WIM splitsen naar SWM bestanden in $OutputPath"
        return $true
    }
    
    $outputSwm = Join-Path -Path $OutputPath -ChildPath "$BaseName.swm"
    
    try {
        # Split WIM to SWM with 3800MB limit (iets onder 4GB voor FAT32 compatibiliteit)
        $result = dism /Split-Image /ImageFile:$WimPath /SWMFile:$outputSwm /FileSize:3800
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WIM succesvol gesplitst naar SWM bestanden" "SUCCESS"
            
            # Controleer hoeveel SWM bestanden zijn aangemaakt
            $swmFiles = Get-ChildItem -Path $OutputPath -Name "$BaseName*.swm"
            Write-Log "Aangemaakt: $($swmFiles.Count) SWM bestanden: $($swmFiles -join ', ')"
            return $true
        } else {
            Write-Log "Fout bij splitsen WIM naar SWM. Exit code: $LASTEXITCODE" "ERROR"
            Write-Log "DISM output: $result" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Exception bij splitsen WIM naar SWM: $_" "ERROR"
        return $false
    }
}

function Get-WimSize {
    param (
        [string]$WimPath
    )
    
    if (Test-Path $WimPath) {
        $sizeBytes = (Get-Item $WimPath).Length
        $sizeGB = [math]::Round($sizeBytes / 1GB, 2)
        Write-Log "WIM bestand grootte: $sizeGB GB"
        return $sizeGB
    }
    return 0
}

function Inject-BootDrivers {
    Write-Log "=== Boot Driver Injectie Gestart ===" "SUCCESS"
    
    # Controleer drivers folder EERST
    $driversBootPath = Join-Path -Path $ScriptDir -ChildPath "drivers-boot"
    if (-not (Test-Path $driversBootPath) -or (Get-ChildItem $driversBootPath -Recurse -Include "*.inf").Count -eq 0) {
        Write-Log "Geen drivers gevonden in drivers-boot folder." "ERROR"
        Write-Host "Geen drivers gevonden in drivers-boot folder." -ForegroundColor Red
        Write-Host "Voeg drivers toe aan de drivers-boot folder en herstart het script." -ForegroundColor Yellow
        Read-Host "Druk Enter om door te gaan..."
        return $false
    }
    
    # Controleer boot.wim in sources folder
    $sourceBootWim = Join-Path -Path $ScriptDir -ChildPath "sources\boot.wim"
    if (-not (Test-Path $sourceBootWim)) {
        Write-Log "boot.wim niet gevonden in sources folder." "ERROR"
        Write-Host "boot.wim niet gevonden in sources folder." -ForegroundColor Red
        Write-Host "Voeg het boot.wim bestand toe aan de map sources en herstart het script." -ForegroundColor Yellow
        Read-Host "Druk Enter om door te gaan..."
        return $false
    }
    
    if (-not (Test-WimFile $sourceBootWim)) {
        Write-Log "boot.wim is beschadigd of ongeldig." "ERROR"
        Write-Host "boot.wim is beschadigd of ongeldig." -ForegroundColor Red
        Read-Host "Druk Enter om door te gaan..."
        return $false
    }
    
    # Ruim export folder op
    $exportBootWim = Join-Path -Path $ScriptDir -ChildPath "sources-export\boot.wim"
    if (Test-Path $exportBootWim) {
        if ($DryRun) {
            Write-Log "DryRun: Zou $exportBootWim verwijderen"
        } else {
            Remove-Item $exportBootWim -Force
            Write-Log "Oude boot.wim uit export folder verwijderd"
        }
    }
    
    # Ruim mount folder op
    $mountBootPath = Join-Path -Path $ScriptDir -ChildPath "mount-boot"
    if (-not (Cleanup-MountPoint $mountBootPath)) {
        return $false
    }
    
    # Kopieer boot.wim naar export folder
    Write-Log "Kopiëren boot.wim naar sources-export folder..."
    if ($DryRun) {
        Write-Log "DryRun: Zou boot.wim kopiëren naar sources-export"
    } else {
        try {
            Copy-Item -Path $sourceBootWim -Destination $exportBootWim -Force
            Write-Log "boot.wim succesvol gekopieerd" "SUCCESS"
        } catch {
            Write-Log "Fout bij kopiëren boot.wim: $_" "ERROR"
            return $false
        }
    }
    
    # Get beschikbare images in boot.wim
    if (-not $DryRun) {
        Write-Log "Ophalen beschikbare images in boot.wim..."
        $bootImageInfo = dism /Get-WimInfo /WimFile:$exportBootWim
        Write-Host "`nBeschikbare images in boot.wim:" -ForegroundColor Cyan
        
        # Parse image info voor betere weergave
        $bootImageLines = $bootImageInfo | Where-Object { $_ -match "Index|Name|Description" }
        $bootImageLines | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        Write-Host ""
    }
    
    # Verwerk beide boot.wim indices (meestal index 1 = Windows PE, index 2 = Windows Setup)
    $bootIndices = @(1, 2)
    $processedBootImages = 0
    
    foreach ($bootIndex in $bootIndices) {
        Write-Log "=== Verwerken boot.wim index $bootIndex ==="
        
        if ($DryRun) {
            Write-Log "DryRun: Zou boot.wim index $bootIndex verwerken"
            $processedBootImages++
            continue
        }
        
        # Test of deze image index bestaat
        $testBootMount = dism /Get-WimInfo /WimFile:$exportBootWim /Index:$bootIndex 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Boot.wim index $bootIndex bestaat niet, overslaan..."
            continue
        }
        
        # Ruim mount folder op voordat we mounten
        if (-not (Cleanup-MountPoint $mountBootPath)) {
            Write-Log "Fout bij opruimen mount point voor index $bootIndex" "ERROR"
            continue
        }
        
        # Mount boot.wim index
        Write-Log "Mounten boot.wim index $bootIndex naar mount-boot folder..."
        $mountResult = dism /Mount-Image /ImageFile:$exportBootWim /Index:$bootIndex /MountDir:$mountBootPath
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fout bij mounten boot.wim index $bootIndex" "WARNING"
            continue
        }
        Write-Log "boot.wim index $bootIndex succesvol gemount" "SUCCESS"
        
        # Injecteer drivers in deze index
        Write-Log "Injecteren drivers in boot.wim index $bootIndex..."
        $injectResult = dism /Image:$mountBootPath /Add-Driver /Driver:$driversBootPath /Recurse
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fout bij injecteren drivers in boot index $bootIndex" "WARNING"
            # Probeer toch te unmounten
            dism /Unmount-Image /MountDir:$mountBootPath /Discard | Out-Null
            continue
        } else {
            Write-Log "Drivers succesvol geinjecteerd in boot.wim index $bootIndex" "SUCCESS"
            $processedBootImages++
        }
        
        # Unmount en save
        Write-Log "Unmounten en opslaan boot.wim index $bootIndex..."
        $unmountResult = dism /Unmount-Image /MountDir:$mountBootPath /Commit
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fout bij unmounten boot.wim index $bootIndex" "ERROR"
            # Probeer discard als laatste redmiddel
            dism /Unmount-Image /MountDir:$mountBootPath /Discard | Out-Null
        } else {
            Write-Log "boot.wim index $bootIndex succesvol unmount en opgeslagen" "SUCCESS"
        }
    }
    
    if ($processedBootImages -eq 0 -and -not $DryRun) {
        Write-Log "Geen boot.wim images succesvol verwerkt!" "ERROR"
        return $false
    }
    
    # Controleer finale boot.wim grootte (mag niet groter dan 3.8GB worden)
    if (-not $DryRun) {
        $finalSize = Get-WimSize $exportBootWim
        if ($finalSize -gt 3.8) {
            Write-Log "WAARSCHUWING: boot.wim is $finalSize GB - dit kan problemen veroorzaken bij installatie!" "WARNING"
            Write-Host "WAARSCHUWING: boot.wim is groter dan 3.8GB - dit kan de installatie verstoren!" -ForegroundColor Red
            Write-Host "Overweeg minder drivers toe te voegen of gebruik gecomprimeerde drivers." -ForegroundColor Yellow
            Read-Host "Druk Enter om door te gaan..."
        }
    }
    
    Write-Log "=== Boot Driver Injectie Voltooid ===" "SUCCESS"
    return $true
}

function Inject-InstallDrivers {
    Write-Log "=== Installation Driver Injectie Gestart ===" "SUCCESS"
    
    # Controleer drivers folder EERST
    $driversInstallPath = Join-Path -Path $ScriptDir -ChildPath "drivers-install"
    if (-not (Test-Path $driversInstallPath) -or (Get-ChildItem $driversInstallPath -Recurse -Include "*.inf").Count -eq 0) {
        Write-Log "Geen drivers gevonden in drivers-install folder." "ERROR"
        Write-Host "Geen drivers gevonden in drivers-install folder." -ForegroundColor Red
        Write-Host "Voeg drivers toe aan de drivers-install folder en herstart het script." -ForegroundColor Yellow
        Read-Host "Druk Enter om door te gaan..."
        return $false
    }
    
    $sourcesPath = Join-Path -Path $ScriptDir -ChildPath "sources"
    $tempWimPath = Join-Path -Path $ScriptDir -ChildPath "temp-wim"
    
    # Zoek install.wim of install.swm
    $installWim = Join-Path -Path $sourcesPath -ChildPath "install.wim"
    $installSwm = Join-Path -Path $sourcesPath -ChildPath "install.swm"
    $workingWim = Join-Path -Path $tempWimPath -ChildPath "install-working.wim"
    
    $isSwmSource = $false
    
    if (Test-Path $installWim) {
        Write-Log "install.wim gevonden - gebruik WIM bestand direct"
        $sourceFile = $installWim
    } elseif (Test-Path $installSwm) {
        Write-Log "install.swm gevonden - SWM naar WIM conversie nodig"
        $isSwmSource = $true
        $sourceFile = $installSwm
        
        # Controleer of alle SWM bestanden aanwezig zijn
        $swmFiles = Get-ChildItem -Path $sourcesPath -Name "install*.swm" | Sort-Object
        Write-Log "Gevonden SWM bestanden: $($swmFiles -join ', ')"
        
        if ($swmFiles.Count -lt 2) {
            Write-Log "Niet alle SWM bestanden gevonden. Verwacht install.swm en install2.swm (etc.)" "ERROR"
            Write-Host "Niet alle SWM bestanden gevonden in sources folder." -ForegroundColor Red
            Write-Host "Zorg ervoor dat alle install*.swm bestanden aanwezig zijn." -ForegroundColor Yellow
            Read-Host "Druk Enter om door te gaan..."
            return $false
        }
    } else {
        Write-Log "Geen install.wim of install.swm gevonden in sources folder." "ERROR"
        Write-Host "Geen install.wim of install.swm gevonden in sources folder." -ForegroundColor Red
        Read-Host "Druk Enter om door te gaan..."
        return $false
    }
    
    # Voor SWM: converteer naar WIM met alleen Windows Pro
    if ($isSwmSource) {
        # Ruim temp folder op
        if (Test-Path $tempWimPath) {
            if ($DryRun) {
                Write-Log "DryRun: Zou temp folder opruimen"
            } else {
                Remove-Item -Path "$tempWimPath\*" -Force -Recurse -ErrorAction SilentlyContinue
                Write-Log "Temp folder opgeruimd"
            }
        }
        
        if (-not $DryRun) {
            # Eerst kijken welke images er zijn
            Write-Log "Controleren beschikbare images in SWM bestand..."
            $swmInfo = dism /Get-WimInfo /WimFile:`"$sourceFile`"
            Write-Host "`nBeschikbare images in SWM bestand:" -ForegroundColor Cyan
            
            # Zoek Windows Pro index
            $proIndex = 0
            $swmInfo | ForEach-Object {
                if ($_ -match "Index\s*:\s*(\d+)") {
                    $currentIndex = [int]$matches[1]
                    $indexFound = $currentIndex
                }
                if ($_ -match "Name\s*:\s*(.+)" -and $_ -match "Pro" -and -not ($_ -match "Pro N")) {
                    $proIndex = $indexFound
                    Write-Host "Gevonden Windows Pro op index $proIndex" -ForegroundColor Green
                }
                if ($_ -match "Index|Name|Description") {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
            
            if ($proIndex -eq 0) {
                # Fallback: probeer index 5 (standaard Windows Pro)
                $proIndex = 5
                Write-Log "Kon Windows Pro niet automatisch vinden, proberen index 5..." "WARNING"
            }
            
            Write-Log "Converteren SWM naar WIM voor Windows Pro (index $proIndex)..."
            
            # Gebruik jouw commando voor SWM naar WIM conversie
            $convertCmd = "dism /Export-Image /SourceImageFile:`"$sourceFile`" /SWMFile:`"install*.swm`" /SourceIndex:$proIndex /DestinationImageFile:`"$workingWim`" /Compress:max /CheckIntegrity"
            Write-Log "DISM commando: $convertCmd"
            
            # Wissel naar sources folder voor wildcard
            Push-Location $sourcesPath
            try {
                $result = dism /Export-Image /SourceImageFile:"install.swm" /SWMFile:"install*.swm" /SourceIndex:$proIndex /DestinationImageFile:$workingWim /Compress:max /CheckIntegrity
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "SWM succesvol geconverteerd naar WIM (alleen Windows Pro)" "SUCCESS"
                } else {
                    Write-Log "Fout bij converteren SWM naar WIM. Exit code: $LASTEXITCODE" "ERROR"
                    Write-Log "DISM output: $result" "ERROR"
                    return $false
                }
            } finally {
                Pop-Location
            }
            
            # Test het geconverteerde bestand
            if (-not (Test-WimFile $workingWim)) {
                Write-Log "Geconverteerde WIM bestand is niet geldig" "ERROR"
                return $false
            }
            
            $sourceFile = $workingWim
        } else {
            Write-Log "DryRun: Zou SWM converteren naar WIM"
            $sourceFile = $workingWim
        }
    }
    
    # Test WIM bestand
    if (-not $DryRun -and -not (Test-WimFile $sourceFile)) {
        Write-Log "WIM bestand is beschadigd of ongeldig." "ERROR"
        Write-Host "WIM bestand is beschadigd of ongeldig." -ForegroundColor Red
        Read-Host "Druk Enter om door te gaan..."
        return $false
    }
    
    # Kopieer WIM naar export folder
    $exportWim = Join-Path -Path $ScriptDir -ChildPath "sources-export\install.wim"
    if (Test-Path $exportWim) {
        if ($DryRun) {
            Write-Log "DryRun: Zou oude install.wim uit export verwijderen"
        } else {
            Remove-Item $exportWim -Force
            Write-Log "Oude install.wim uit export folder verwijderd"
        }
    }
    
    Write-Log "Kopiëren install.wim naar export folder..."
    if ($DryRun) {
        Write-Log "DryRun: Zou install.wim kopiëren naar export"
    } else {
        try {
            Copy-Item -Path $sourceFile -Destination $exportWim -Force
            Write-Log "install.wim succesvol gekopieerd" "SUCCESS"
        } catch {
            Write-Log "Fout bij kopiëren install.wim: $_" "ERROR"
            return $false
        }
    }
    
    # Ruim mount folder op
    $mountInstallPath = Join-Path -Path $ScriptDir -ChildPath "mount-install"
    if (-not (Cleanup-MountPoint $mountInstallPath)) {
        return $false
    }
    
    # Get available images
    if (-not $DryRun) {
        Write-Log "Ophalen beschikbare images in install.wim..."
        $imageInfo = dism /Get-WimInfo /WimFile:`"$exportWim`"
        Write-Host "`nBeschikbare images in install.wim:" -ForegroundColor Cyan
        
        # Parse image info voor betere weergave
        $imageLines = $imageInfo | Where-Object { $_ -match "Index|Name|Description" }
        $imageLines | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        Write-Host ""
    }
    
    # Bepaal het aantal images (na SWM conversie waarschijnlijk maar 1)
    $maxIndex = if ($DryRun) { 1 } else { 
        try {
            $wimInfo = dism /Get-WimInfo /WimFile:`"$exportWim`"
            $indexLines = $wimInfo | Where-Object { $_ -match "Index\s*:\s*(\d+)" }
            if ($indexLines) {
                ($indexLines | ForEach-Object { [int]($_ -replace ".*Index\s*:\s*(\d+).*", '$1') } | Measure-Object -Maximum).Maximum
            } else {
                1  # Na conversie waarschijnlijk maar 1 image
            }
        } catch {
            1  # fallback
        }
    }
    
    $processedImages = 0
    
    # Verwerk elke image index (waarschijnlijk maar 1 na SWM conversie)
    for ($index = 1; $index -le $maxIndex; $index++) {
        Write-Log "=== Verwerken install.wim index $index ==="
        
        if ($DryRun) {
            Write-Log "DryRun: Zou install.wim index $index verwerken"
            $processedImages++
            continue
        }
        
        # Test of deze image index bestaat
        $testMount = dism /Get-WimInfo /WimFile:`"$exportWim`" /Index:$index 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Image index $index bestaat niet, overslaan..."
            continue
        }
        
        # Ruim mount folder op voordat we mounten
        if (-not (Cleanup-MountPoint $mountInstallPath)) {
            Write-Log "Fout bij opruimen mount point voor index $index" "ERROR"
            continue
        }
        
        # Mount image
        Write-Log "Mounten install.wim index $index..."
        $mountResult = dism /Mount-Image /ImageFile:`"$exportWim`" /Index:$index /MountDir:`"$mountInstallPath`"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fout bij mounten install.wim index $index. Exit code: $LASTEXITCODE" "WARNING"
            continue
        }
        Write-Log "install.wim index $index succesvol gemount" "SUCCESS"
        
        # Injecteer drivers
        Write-Log "Injecteren drivers in install.wim index $index..."
        $injectResult = dism /Image:`"$mountInstallPath`" /Add-Driver /Driver:`"$driversInstallPath`" /Recurse
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fout bij injecteren drivers in index $index" "WARNING"
            # Probeer toch te unmounten
            dism /Unmount-Image /MountDir:`"$mountInstallPath`" /Discard | Out-Null
            continue
        } else {
            Write-Log "Drivers succesvol geinjecteerd in index $index" "SUCCESS"
            $processedImages++
        }
        
        # Unmount en save
        Write-Log "Unmounten install.wim index $index..."
        $unmountResult = dism /Unmount-Image /MountDir:`"$mountInstallPath`" /Commit
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Fout bij unmounten install.wim index $index" "ERROR"
            # Probeer discard als laatste redmiddel
            dism /Unmount-Image /MountDir:`"$mountInstallPath`" /Discard | Out-Null
        } else {
            Write-Log "install.wim index $index succesvol unmount en opgeslagen" "SUCCESS"
        }
    }
    
    if ($processedImages -eq 0) {
        Write-Log "Geen images succesvol verwerkt!" "ERROR"
        return $false
    }
    
    if ($isSwmSource) {
        Write-Log "SWM naar WIM conversie en driver injectie succesvol voltooid!" "SUCCESS"
    }
    
    # Controleer finale WIM grootte en splits indien nodig voor FAT32 compatibiliteit
    if (-not $DryRun) {
        $finalSize = Get-WimSize $exportWim
        Write-Log "Finale install.wim grootte: $finalSize GB"
        
        if ($finalSize -gt 3.8) {
            Write-Log "WIM bestand is groter dan 3.8GB - splitsen naar SWM bestanden voor FAT32 compatibiliteit..." "WARNING"
            Write-Host "Install.wim is $finalSize GB - splitsen naar SWM bestanden..." -ForegroundColor Yellow
            
            # Verwijder eventuele oude SWM bestanden uit export folder
            $oldSwmFiles = Get-ChildItem -Path (Split-Path $exportWim) -Name "install*.swm" -ErrorAction SilentlyContinue
            if ($oldSwmFiles) {
                $oldSwmFiles | ForEach-Object {
                    Remove-Item -Path (Join-Path (Split-Path $exportWim) $_) -Force -ErrorAction SilentlyContinue
                }
                Write-Log "Oude SWM bestanden verwijderd uit export folder"
            }
            
            # Splits WIM naar SWM bestanden
            $exportSwm = Join-Path -Path (Split-Path $exportWim) -ChildPath "install.swm"
            $splitResult = dism /Split-Image /ImageFile:`"$exportWim`" /SWMFile:`"$exportSwm`" /FileSize:3800
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "WIM succesvol gesplitst naar SWM bestanden" "SUCCESS"
                
                # Controleer hoeveel SWM bestanden zijn aangemaakt
                $newSwmFiles = Get-ChildItem -Path (Split-Path $exportWim) -Name "install*.swm"
                Write-Log "Aangemaakt: $($newSwmFiles.Count) SWM bestanden: $($newSwmFiles -join ', ')" "SUCCESS"
                Write-Host "Aangemaakt: $($newSwmFiles.Count) SWM bestanden voor FAT32 compatibiliteit" -ForegroundColor Green
                
                # Verwijder het originele grote WIM bestand
                Remove-Item $exportWim -Force
                Write-Log "Origineel groot WIM bestand verwijderd - gebruik nu de SWM bestanden"
                
                Write-Host "`nLet op: Gebruik de install*.swm bestanden in je ISO (niet install.wim)" -ForegroundColor Cyan
            } else {
                Write-Log "Fout bij splitsen WIM naar SWM. Exit code: $LASTEXITCODE" "ERROR"
                Write-Log "DISM split output: $splitResult" "ERROR"
                Write-Host "Fout bij splitsen - groot WIM bestand behouden" -ForegroundColor Red
                Write-Host "Handmatig splitsen kan nodig zijn voor FAT32 compatibiliteit" -ForegroundColor Yellow
            }
        } else {
            Write-Log "WIM bestand is $finalSize GB - splitsen niet nodig" "SUCCESS"
            Write-Host "Install.wim is $finalSize GB - past binnen FAT32 limiet" -ForegroundColor Green
        }
    }
    
    Write-Log "Succesvol verwerkt: $processedImages van $maxIndex images" "SUCCESS"
    Write-Log "=== Installation Driver Injectie Voltooid ===" "SUCCESS"
    return $true
}

function Show-Menu {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "    Windows 11 Driver Injectie Tool   " -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Selecteer een optie:" -ForegroundColor White
    Write-Host ""
    Write-Host "B - Boot driver injectie (boot.wim beide indices)" -ForegroundColor Green
    Write-Host "I - Installation driver injectie (install.wim/swm)" -ForegroundColor Green  
    Write-Host "A - Alle driver injecties (boot + install)" -ForegroundColor Yellow
    Write-Host "Q - Afsluiten" -ForegroundColor Red
    Write-Host ""
	Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "                Read ME               " -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "Plaats de drivers die nodig zijn in het"
	Write-Host " installatie image(boot) ook in de installatie"
	Write-Host " drivers! Dit om BSOD te voorkomen."
	Write-Host ""
}

function Handle-MenuSelection {
    do {
        Clear-Host
        Show-Menu
        $choice = Read-Host "Voer uw keuze in (B/I/A/Q)"
        
        switch ($choice.ToUpper()) {
            "B" {
                Clear-Host
                Write-Host "Boot driver injectie geselecteerd." -ForegroundColor Yellow
                Write-Log "Gebruiker selecteerde Boot driver injectie."
                
                $success = Inject-BootDrivers
                if ($success -eq $true) {
                    Write-Host "`nBoot driver injectie succesvol voltooid!" -ForegroundColor Green
                } else {
                    Write-Host "`nBoot driver injectie mislukt. Controleer de log voor details." -ForegroundColor Red
                }
                
                Read-Host "`nDruk Enter om door te gaan..."
            }
            "I" {
                Clear-Host
                Write-Host "Installation driver injectie geselecteerd." -ForegroundColor Yellow
                Write-Log "Gebruiker selecteerde Installation driver injectie."
                
                $success = Inject-InstallDrivers
                if ($success -eq $true) {
                    Write-Host "`nInstallation driver injectie succesvol voltooid!" -ForegroundColor Green
                } else {
                    Write-Host "`nInstallation driver injectie mislukt. Controleer de log voor details." -ForegroundColor Red
                }
                
                Read-Host "`nDruk Enter om door te gaan..."
            }
            "A" {
                Write-Host ""
                Write-Host "Alle driver injecties geselecteerd." -ForegroundColor Yellow
                Write-Log "Gebruiker selecteerde Alle driver injecties."
                
                $bootSuccess = Inject-BootDrivers
                $installSuccess = Inject-InstallDrivers
                
                if ($bootSuccess -and $installSuccess) {
                    Write-Host "Alle driver injecties succesvol voltooid!" -ForegroundColor Green
                } elseif ($bootSuccess -or $installSuccess) {
                    Write-Host "Een of meerdere driver injecties zijn mislukt. Controleer de log voor details." -ForegroundColor Yellow
                } else {
                    Write-Host "Alle driver injecties zijn mislukt. Controleer de log voor details." -ForegroundColor Red
                }
                
                Read-Host "`nDruk Enter om door te gaan..."
            }
            "Q" {
                Write-Host ""
                Write-Host "Script wordt afgesloten." -ForegroundColor Yellow
                Write-Log "Gebruiker heeft het script afgesloten."
                Start-Sleep 2
                exit 0
            }
            default {
                Write-Host ""
                Write-Host "Ongeldige keuze. Selecteer alstublieft B, I, A, of Q." -ForegroundColor Red
                Start-Sleep 2
            }
        }
    } while ($true)
}

# Main Execution
try {
    Write-Log "=== Script Gestart ===" "SUCCESS"
    Write-Host "Windows 11 Driver Injectie Tool v1.2.0" -ForegroundColor Cyan
    Write-Host "Met ondersteuning voor SWM bestanden (>3.8GB)" -ForegroundColor Gray
    Write-Host "Boot.wim wordt geinjecteerd in beide indices (PE + Setup)" -ForegroundColor Gray
    Write-Host "Logbestand: $LogFile" -ForegroundColor Gray
    Write-Host ""
    
    # Controleer PowerShell versie
    if (-not (Check-PowerShellVersion)) {
        Read-Host "Druk Enter om door te gaan ondanks de waarschuwing..."
    }
    
    # Controleer administrator rechten
    if (-not (Check-Admin)) {
        Write-Host "Administrator rechten vereist. Script wordt herstart..." -ForegroundColor Yellow
        Restart-AsAdmin
        return
    }
    
    # Controleer DISM beschikbaarheid
    if (-not (Check-DismAvailability)) {
        Write-Log "DISM is niet beschikbaar. Script kan niet verder." "ERROR"
        Read-Host "Druk Enter om af te sluiten..."
        exit 1
    }
    
    # Controleer schijfruimte
    if (-not (Check-DiskSpace)) {
        Read-Host "Druk Enter om af te sluiten..."
        exit 1
    }
    
    # Maak benodigde mappen aan
    if (-not (Create-Folders)) {
        Write-Log "Fout bij aanmaken mappen. Script kan niet verder." "ERROR"
        Read-Host "Druk Enter om af te sluiten..."
        exit 1
    }
    
    # Start interactieve menu
    Handle-MenuSelection
    
    Write-Log "=== Script Voltooid ===" "SUCCESS"
    
} catch {
    Write-Log "Onverwachte fout: $_" "ERROR"
    Write-Host "Er is een onverwachte fout opgetreden. Controleer de log voor details." -ForegroundColor Red
    Read-Host "Druk Enter om af te sluiten..."
    exit 1
}
