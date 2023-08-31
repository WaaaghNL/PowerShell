## How to use:
## Place this script in the root of new app and package the application as a intunewin file.
##
## Contact MobiCoach to get the latest installer and add the msi name to the config below. Also ask them for custom MobiScout.exe.config and Remote.config files
## 
## Install command:   powershell.exe -ExecutionPolicy Bypass -file MobiScoutSuite.ps1 -Mode Install
## Uninstall command: powershell.exe -ExecutionPolicy Bypass -file MobiScoutSuite.ps1 -Mode Uninstall
##
## Create the folowing detection rule
## Rules format:     Manually configure detection rules
## Rule type:        File
## Path:             C:\Program Files (x86)\MobiCoach\MobiScout Suite
## File or folder:   MobiScout.exe
## Detection method: File or folder exists

##
## Parameters, Sorry you can't create code above this. Blame Microsoft!
##
Param(
	[Parameter(Mandatory=$true, HelpMessage="Accepted values: Install, and Uninstall")]
	[ValidateSet("Install", "Uninstall")]
	[String] $Mode
)

##
## Config
##
$InstallPath = "C:\Program Files (x86)\MobiCoach\MobiScout Suite"
$InstallName = "MobiScout Suite"
$InstallMSI = "MobiScoutSuite3.1.5.msi"
$InstallDataBase = "DATABASE"

##
## Script
##
if ($Mode -eq "Install"){	
	## Test if program folder exists, if not create it.
	if(!(Test-Path $InstallPath -ErrorAction SilentlyContinue)){
		## Create Path
		New-Item -ItemType Directory -Force -Path $InstallPath
	}
	
	## Install MobiScout Suite
	Write-Verbose "Install Application"
    Start-Process msiexec.exe -NoNewWindow -ArgumentList "/I $InstallMSI /quiet /qn"

	## Install Backend Info
	Write-Verbose "Installing Backend Info"
	
	##Wait untill msiexec is done
    Write-Verbose "Waiting for the installation to create the files in Program Files"	
	while (!(Test-Path "$InstallPath\MobiScout.exe.config" -ErrorAction SilentlyContinue) -and !(Test-Path "$InstallPath\Remote.config" -ErrorAction SilentlyContinue))
	{
		## Write-Host "Waiting for the installation to create the folder in Program Files"
		Start-Sleep -Seconds 1
	}
	Copy-Item -Path ".\MobiScout.exe.config" -Destination "$InstallPath\MobiScout.exe.config" -Recurse -Force
	Copy-Item -Path ".\Remote.config" -Destination "$InstallPath\Remote.config" -Recurse -Force
	
	## Kill ShortcutWizard
	$limit = (Get-Date).AddMinutes(1)
	do {  
		$ProcessesFound = Get-Process -name "ShortcutWizard" -ErrorAction SilentlyContinue
		if ($ProcessesFound) {
            ## If quit to early the install will break!
            Start-Sleep -Seconds 1

            ## Stop ShortcutWizard
			Write-Verbose "Stop process: ShortcutWizard"
			Stop-Process -Name "ShortcutWizard"
		}
	} until ($ProcessesFound -or (Get-Date) -ge $limit)
	
	## Add Shortcut to start menu
	$shell = New-Object -comObject WScript.Shell
    $shortcut = $shell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\MobiScout.lnk")
	$shortcut.TargetPath = "$InstallPath\MobiScout.exe"
	$shortcut.Arguments = "DSN=$InstallDataBase"
	$shortcut.IconLocation = "$InstallPath\savanna1.ico"
	$shortcut.WorkingDirectory  = "C:\Program Files (x86)\MobiCoach\MobiScout Suite\"
	$shortcut.Save()

    ## Clean up
    Start-Sleep -Seconds 1
    Remove-Item "$InstallPath\*.tmp"
}

if ($Mode -eq "Uninstall"){	
	## Remove Backend Info
	Write-Verbose "Remove Backend Info"
	Remove-Item "$InstallPath\MobiScout.exe.config" -ErrorAction SilentlyContinue
	Remove-Item "$InstallPath\Remote.config" -ErrorAction SilentlyContinue
	Remove-Item "$InstallPath\InstallProcedure.InstallState" -ErrorAction SilentlyContinue ## Remove it so it's gone after an uninstall
	
	## Remove Shortcut from startmenu
	Remove-Item "C:\ProgramData\Microsoft\Windows\Start Menu\MobiScout.lnk" -ErrorAction SilentlyContinue
	
    ## Find Application GUID
    $process = Get-ProgramUninstallString -Filter "MobiScout"

    ## Remove Application
	Write-Verbose "Remove Application"
	msiexec /x $process.guid /qn
}

Write-Verbose "End of Script!"


##
## Functions!
##
function Get-ProgramUninstallString {
    [CmdletBinding(DefaultParameterSetName = "ByName")]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(
            ParameterSetName = "ByName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias(
            "DisplayName"
        )]
        [String[]]
        $Name,
        [Parameter(
            ParameterSetName = "ByFilter"
        )]
        [String]
        $Filter = "*",
        [Parameter()]
        [Switch]
        $ShowNulls
    )
    begin {
        try {
            if (Test-Path -Path "HKLM:\SOFTWARE\WOW6432Node") {
                $programs = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction Stop
            }
            $programs += Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction Stop
            $programs += Get-ItemProperty -Path "Registry::\HKEY_USERS\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue
        } catch {
            Write-Error $_
            break
        }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq "ByName") {
            foreach ($nameValue in $Name) {
                $programs = $programs.Where({
                    $_.DisplayName -eq $nameValue
                })
            }
        } else {
            $programs = $programs.Where({
                $_.DisplayName -like "*$Filter*"
            })
        }

        if ($null -ne $programs) {
            if (-not ($ShowNulls.IsPresent)) {
                $programs = $programs.Where({
                    -not [String]::IsNullOrEmpty(
                        $_.UninstallString
                    )
                })
            }
            $output = $programs.ForEach({
                [PSCustomObject]@{
                    Name = $_.DisplayName
                    Version = $_.DisplayVersion
                    Guid = $_.PSChildName
                    UninstallString = $_.UninstallString
                }
            })
            Write-Output -InputObject $output
        }
    }
}