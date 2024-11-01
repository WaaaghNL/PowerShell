#Variables
$TenantNAME = "TENANTNAME"
$TenantID = "TenantID"
$AppID = "APPID"
$AppSecret = "APPSECRET"

$sleepBeforeReboot = 10 #tijd in minuten voor de reboot


# Bovenstaande informatie kun je vinden door een applicatie aan te maken met de stappen van https://www.osdeploy.com/guides/autopilot-app-registration

####################################
### Do NOT edit below this line! ###
####################################

function wait-for-network ($tries) {
        while (1) {
		# Get a list of DHCP-enabled interfaces that have a 
		# non-$null DefaultIPGateway property.
                $x = gwmi -class Win32_NetworkAdapterConfiguration `
                        -filter DHCPEnabled=TRUE |
                                where { $_.DefaultIPGateway -ne $null }

		# If there is (at least) one available, exit the loop.
                if ( ($x | measure).count -gt 0 ) {
					Write-Host "Netwerk connectie: CHECK!" -ForegroundColor Green
                    break
                }

		# If $tries > 0 and we have tried $tries times without success, throw an error.
                if ( $tries -gt 0 -and $try++ -ge $tries ) {
						Write-Host "Geen netwerk na $try pogingen, Controleer je verbinding en herstart dit script." -ForegroundColor Red
						exit
                }

		# Wacht voor een seconden en probeer opnieuw
                start-sleep -s 2
				Write-Host "Wachten op netwerk..." -ForegroundColor Yellow
        }
}

wait-for-network 50

if (Test-Connection 8.8.8.8 -Quiet) { 
	Write-Host "Internet: CHECK!" -ForegroundColor Green
}
else{
	Write-Host "Internet: FAILED! Kan geen verbinding maken met 8.8.8.8" -ForegroundColor Red
	exit
}

if ($TenantID -ne $null -and $TenantID -ne "" -and
    $AppID -ne $null -and $AppID -ne "" -and
    $AppSecret -ne $null -and $AppSecret -ne "")
{
    # All three variables are not null or empty
    Write-Host "Verbinden met Intune doormiddel van een app-based registratie." -ForegroundColor Green
    powershell D:\Get-WindowsAutopilotInfo.ps1 -Online -TenantId $TenantID -AppID $AppID -AppSecret $AppSecret
}
else
{
    # At least one variable is null or empty
    Write-Host "Niet alle configuratie items zijn ingesteld. Verbinden met Intune via de handmatige manier." -ForegroundColor Yellow
    Write-Host "Tip voer de App-based registratie gegevens toe aan de config." -ForegroundColor Yellow
    powershell D:\Get-WindowsAutopilotInfo.ps1 -Online
}

Write-Host "`r`n"
Write-Host "We gaan even een dutje doen van $sleepBeforeReboot minuten om intune de kans te geven een aantal zaken gereed te maken." -ForegroundColor Yellow
Write-Host "Vervolgens gaan we opnieuw opstarten en zou je verwelkomt moeten worden met Welkom bij $TenantNAME." -ForegroundColor Yellow
Write-Host "Je kunt dit script veilig afbreken met CTRL + C" -ForegroundColor DarkRed

# Slapen voor reboot met progressbar
$tijdInSeconden = $sleepBeforeReboot*60
for ($i = 1; $i -le $tijdInSeconden; $i++) {
    # Update progress bar
    $prcentageCompleet = ($i / $tijdInSeconden) * 100
    $tijdOver = $tijdInSeconden-$i
    Write-Progress -Activity "Wachten op reboot" -Status "Nog $tijdOver seconden van $sleepBeforeReboot minuten" -PercentComplete $prcentageCompleet

    Start-Sleep -s 1
}

# Bliep voor aandacht omdat de countdown zo lang duurt, Geeft error in VM omdat deze geen buzzer hebben.
[System.Console]::Beep(1109,200);

#Reboot
shutdown -r -t 5
