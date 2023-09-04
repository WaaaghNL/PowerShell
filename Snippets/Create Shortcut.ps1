## https://learn.microsoft.com/en-us/troubleshoot/windows-client/admin-development/create-desktop-shortcut-with-wsh
## https://learn.microsoft.com/en-us/answers/questions/1163030/how-to-create-a-shortcut-to-a-folder-with-powershe

$shell = New-Object -comObject WScript.Shell
## To Location
$shortcut = $shell.CreateShortcut("[Target path of shortcut]\Shortcut Name.lnk")
## EOF: To Location
$shortcut.IconLocation = "C:\myicon.ico"
$shortcut.TargetPath = "C:\Windows\Explorer.exe"
$shortcut.Arguments = """\\machine\share\folder"""
$shortcut.Hotkey = "ALT+CTRL+F"
$shortcut.Save()
