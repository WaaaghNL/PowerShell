## Exitcodes
## 0/1707 = Success
## 3010 = Soft Reboot
## 1641 = Hard Reboot
## 1618 = Retry

## Please create these exit codes for debugging
## 991 = Failed, Please install winget
## 992 = Failed, Incorrect Mode, Accepted values: Install, Uninstall, Update, and Search


Param
    (
        [Parameter(Mandatory = $true, HelpMessage="Accepted values: Install, Uninstall, Update, and Search")] [ValidateSet("Install", "Uninstall", "Update", "Search")] [string] $Mode,
        [Parameter(Mandatory = $true, HelpMessage="Enter the id of the winget package. You can find it on https://winget.run")] [string] $PackageId
    )

## Locate Winget installation
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
Write-Host "ResolveWingetPath: $ResolveWingetPath" -ForegroundColor Yellow

if (Test-Path -Path $ResolveWingetPath){


    Function Set-PathVariable {
        param (
            [string]$AddPath,
            [string]$RemovePath,
            [ValidateSet('Process', 'User', 'Machine')]
            [string]$Scope = 'Process'
        )
        $regexPaths = @()
        if ($PSBoundParameters.Keys -contains 'AddPath') {
            $regexPaths += [regex]::Escape($AddPath)
        }

        if ($PSBoundParameters.Keys -contains 'RemovePath') {
            $regexPaths += [regex]::Escape($RemovePath)
        }
    
        $arrPath = [System.Environment]::GetEnvironmentVariable('PATH', $Scope) -split ';'
        foreach ($path in $regexPaths) {
            $arrPath = $arrPath | Where-Object { $_ -notMatch "^$path\\?" }
        }
        $value = ($arrPath + $addPath) -join ';'
        [System.Environment]::SetEnvironmentVariable('PATH', $value, $Scope)
    }


    ## $WingetPath = $ResolveWingetPath[-1].Path
    ## Set-Location $WingetPath
    ## Write-Host "WingetPath: $WingetPath" -ForegroundColor Yellow

    Set-PathVariable -AddPath $ResolveWingetPath    

    if ($Mode -eq "Install"){
        Write-Host "Install: $PackageId!" -ForegroundColor Green
        winget.exe install --id $PackageId --silent --accept-source-agreements --accept-package-agreements
        exit $LASTEXITCODE
    } 
    elseif ($Mode -eq "Uninstall"){
        Write-Host "Uninstall: $PackageId!" -ForegroundColor Red
        winget.exe uninstall --id $PackageId --silent
        exit $LASTEXITCODE
    }
    elseif ($Mode -eq "Update"){
        Write-Host "Update: $PackageId!" -ForegroundColor Yellow        
        winget.exe update --id $PackageId --silent --accept-source-agreements --accept-package-agreements
        exit $LASTEXITCODE
    }
    elseif ($Mode -eq "Search"){
        Write-Host "Search: $PackageId" -ForegroundColor Yellow
        winget.exe search --id $PackageId
        exit $LASTEXITCODE
    }
    else{
        Write-Host "Incorrect use of the mode function" -ForegroundColor Red
        exit 992
    }

} else{
    Write-Host "Winget Not Found, Please install Winget as a system program" -ForegroundColor Red
    exit 991
}