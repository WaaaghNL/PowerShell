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
 
$Installed = Get-ProgramUninstallString -Name "Sentinel Agent"
IF ($Installed.Version -ge "24.1.257"){
    #$Output = 'True'
    Write-Output "A version of $($installed[0].Name) is installed"
    exit 0
} else {
    #$Output = 'False'
    Write-Output "The software is not installed"
    exit 1
}