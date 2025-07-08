# PRE-Installation Instructions

## 1. To use this script you need the folowing Information
- Management URL, This is the url of the SentinelOne Management interface where you manage the contacts
- SiteToken, This token is needed to kick off the script. This one can be found SentinelOne Management interface > Site > Default Site > Agent Management > Packages > On top of the page
- APIToken, This token is needed to download the latest version of the installer. Instructions to create this Token can be found below.
- We check in the script for a network connection using a ping to Quad9 you can change that 

## 2. Create APIToken
To create a token you need to take the folowing steps, We strongly advice to use an account with only viewing rights!
1. Login to the Management interface
2. Navigate to your envirement without selecting a site
3. Navigate to "Policy & Settings"
4. Select Service Users
5. Click "New Service User
6. Fill in the requested information
7. Choose an Expiration Date (1W until 2 Years)
8. Select your account/tenant name
9. Select Role Viewer
10. Click Create Service User
11. Save the token. It's only showed once!
12. Create a reminder in your calandar to update the APIToken.

## 3. Edit the Invoke-AppDeployToolkit.ps1 file
1. Open `SentinelOneWindowsInstallation\Invoke-AppDeployToolkit.ps1`
2. Edit Line `122` and set the variable `S1apitoken` with the APIToken.
3. Edit line `123` and set the variable `S1URL` to the SentinelOne Management URL.
4. Edit line `124` if you want to disable network checks | Input: `$true` or `$false` Default: `$true`
5. Edit line `125` if you don't want to use Quad9 for the ping | Input: `IP` Default: `9.9.9.9`

# Intune instructions

## Package
. Package the contents of the "SentinelOneWindowsInstallation" folder with the Intune Prep Tool (Latest version: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)

## Create the app in intune
Create an `Windows app (Win32)` application and use the settings below on there step

### Add app tab
We have a logo in the root folder that you can use.

### Program tab
. Set the install command `powershell -Noprofile -executionpolicy bypass -file .\Invoke-AppDeployToolkit.ps1 -Sitetoken <SITETOKEN>` and replace `<SITETOKEN>` with your own token.
. Set the uninstall command `powershell -Noprofile -executionpolicy bypass -file .\invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall`
. Set `Allow available uninstall` to `No`
. Set `Install behavior` to `System`
. Create errorcode `69001` and `69002` with status FAILED

### Requirements tab
. Set the `Check operating system architecture` to `Install on x64 system`
. Set `Minimum operating system` to `Windows 10 21H1`

### Detection tab
. Set `Rules format` to `Use a custom detection script`
. Upload to `Script file` the detection script found in `"SentinelOneDetection\Detection.ps1"`

# Uninstall instructions
Remove the application via the SentinelOne Management interface! Yes it's that simple.

# Special Errorcodes
- 69001: Can't ping the internet (We ping Quad9 `9.9.9.9` if this is blocked on your network change line `125` in `SentinelOneWindowsInstallation/Invoke-AppDeployToolkit.ps1`)