## Special Thanks to carcheky (https://gist.github.com/carcheky/981fda4af8e5aac73d0ca8558947ffbb) for publishing a bigger list of tweaks

## https://answers.microsoft.com/en-us/windows/forum/all/turn-off-windows-spotlight-fun-facts/f96d5c6e-3150-469c-bc0f-d847ba0149b4
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "RotatingLockScreenEnabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "RotatingLockScreenOverlayEnabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "SlideshowEnabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue

## https://www.tenforums.com/tutorials/30869-turn-off-tip-trick-suggestion-notifications-windows-10-a.html
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "SubscribedContent-338387Enabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue

## https://techjourney.net/disable-show-suggestions-occasionally-in-start-in-windows-10/
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "SubscribedContent-338388Enabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue

## https://superuser.com/questions/1406686/keep-windows-10-lock-screen-spotlight-pictures-but-turn-off-all-texts-hints-ball
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "SubscribedContent-338389Enabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue

## https://www.tenforums.com/tutorials/100541-turn-off-suggested-content-settings-app-windows-10-a.html
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "PreInstalledAppsEverEnabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue

## https://www.tenforums.com/tutorials/24117-turn-off-app-suggestions-start-windows-10-a.html
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name "SystemPaneSuggestionsEnabled" -Value 0 -PropertyType "Dword" -Force -ea SilentlyContinue
