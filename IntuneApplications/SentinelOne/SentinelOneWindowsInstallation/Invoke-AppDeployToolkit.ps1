<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

PSAppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2025 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), or NonInteractive (dialogs without prompts) mode.

NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru
Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -AllowRebootPassThru

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [PSDefaultValue(Help = 'Install', Value = 'Install')]
    [System.String]$DeploymentType,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [PSDefaultValue(Help = 'Interactive', Value = 'Interactive')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging,

    [Parameter(Mandatory = $true)]
    $SiteToken
)

##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = 'SentinelOne'
    AppName = 'SentinelOne'
    AppVersion = '-'
    AppArch = '64 Bit'
    AppLang = 'EN'
    AppRevision = '02'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.1'
    AppScriptDate = '2025-08-13'
    AppScriptAuthor = 'Team Managed Workplace'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = 'Install SentinelOne Agent'
    InstallTitle = 'Install SentinelOne Agent'

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.1.0'
    DeployAppScriptParameters = $PSBoundParameters
}

$scriptSession = @{
    # Script variables.
    S1ApiToken = ''
    S1URL = ''
}

function Install-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
    #Show-ADTInstallationWelcome -CloseProcesses iexplore -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

    ## Show Progress Message (with the default message).
    #Show-ADTInstallationProgress

    ## Custome Functions
    Function Get-S1DownloadlatestAgent {
        [CmdletBinding()]
        param(
            [Parameter(Position = 0, Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$apitoken,
            [Parameter(Position = 1, Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$url
        )

        #Config voor de Authenticatie naar SentinelOne
        $url = $url.replace('https://','')
        $url = $url.replace('http://','')
        $global:s1config = @{
            apiToken = $apitoken
            #email = Read-Host "What is your Sentinel One Username?"
            url = $url
            headers = @{
                "Authorization" = "ApiToken $($apiToken)"
                "Content-Type" = "application/json"
            }
        }
		
		Write-ADTLogEntry -Message "Getting 401 errors? API key presumably expired" -Severity 2

        #Gathering all the agents and select te latest version
        $ListAllAgents = (Invoke-RestMethod -Uri "https://$($s1config.url)/web/api/v2.1/update/agent/packages?limit=1000" -Method 'GET' -Headers $s1config.headers).data
		
		
        $LatestAgent = $ListAllAgents | Where-Object {$_.osType -eq 'windows' `
                                        -and $_.fileExtension -like "*exe*" `
                                        -and $_.minorVersion -eq 'ga' `
                                        -and $_.osArch -like "*64 bit*"} | Sort-Object majorVersion -Descending | Select-Object -First 1

        #Create a Download location
        $OutFilePath = 'C:\ProgramData\Automation\Intune_Apps\SentinelOne'
        New-Item -Path $OutFilePath -ItemType Directory -ErrorAction SilentlyContinue -Force | Out-Null
        Remove-Item -Path "$OutFilePath\$($LatestAgent.fileName)" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

        #Download the latest agent
        Invoke-WebRequest -Uri $LatestAgent.link -Headers $s1config.headers -OutFile "$OutFilePath\$($LatestAgent.fileName)"
    }

    #Download the software	
    Get-S1DownloadlatestAgent -apitoken $scriptSession.S1ApiToken -url $scriptSession.S1URL
    ##================================================
    ## MARK: Install
    ##================================================
    ## Perform DBeaver Installation
    $OutFilePath = 'C:\ProgramData\Automation\Intune_Apps\SentinelOne'
    $files = Get-ChildItem -Path $OutFilePath -File -Recurse -ErrorAction SilentlyContinue

    $exePath = $files | Where-Object { $_.Name -match 'SentinelOneInstaller*' }
    if ($exePath.Count -gt 0) {
        Show-ADTInstallationProgress -StatusMessage 'Installing SentinelOne Agent. Please Wait...'
        Start-ADTProcess -FilePath "$($exePath.FullName)" -ArgumentList "-t $SiteToken -q" -WindowStyle 'Hidden'
    }
    else {
        Write-ADTLogEntry -Message "SentinelOne installer was not found. Installation aborted." -Severity 2
        Show-ADTInstallationPrompt -Message 'SentinelOne installer was not found. Installation aborted.' -ButtonRightText 'OK'
    }
    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>
	$installDirectoryPath = "C:\ProgramData\Automation\Intune_Apps\SentinelOne"

	Show-ADTInstallationProgress -StatusMessage 'Clean up after myself. Please Wait...'
	if (Test-Path $installDirectoryPath) {
		#Remove-Item -Path $installDirectoryPath -Recurse -Force
		Write-ADTLogEntry -Message "SentinelOne installer folder removed with all contents." -Severity 1
	} else {
		Write-Output "Directory does not exist."
		Write-ADTLogEntry -Message "SentinelOne installer folder was not found." -Severity 2
	}
	
    ## Display a message at the end of the install.
    if (!$adtSession.UseDefaultMsi)
    {
        #Show-ADTInstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
    }
}

function Uninstall-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Uninstallation tasks here>
	Write-ADTLogEntry -Message "SentinelOne cant be removed using this script. Please use the SentinelOne management interface" -Severity 3
	Show-ADTInstallationPrompt -Message 'Please remove the application using the SentinelOne management interface' -ButtonRightText 'OK' -Icon Information -NoWait


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
}

function Repair-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"))
    {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else
    {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.6' } -Force
    try
    {
        $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @iadtParams -PassThru
    }
    catch
    {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process
        {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally
{
    Remove-Module -Name PSAppDeployToolkit* -Force
}

