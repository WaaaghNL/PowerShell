$fileItems = @(
'LibreBarcode39Extended-Regular.ttf'
'LibreBarcode39ExtendedText-Regular.ttf'
'LibreBarcode39-Regular.ttf'
'LibreBarcode39Text-Regular.ttf'
'LibreBarcode128-Regular.ttf'
'LibreBarcode128Text-Regular.ttf'
'LibreBarcodeEAN13Text-Regular.ttf'
)

$registryItems = @(
'Libre Barcode 39 Extended Regular (TrueType)'
'Libre Barcode 128 Regular (TrueType)'
'Libre Barcode 39 Text Regular (TrueType)'
'Libre Barcode 39 Regular (TrueType)'
'Libre Barcode 39 Extended Text Regular (TrueType)'
'Libre Barcode 128 Text Regular (TrueType)'
'Libre Barcode EAN13 Text Regular (TrueType)'
)

$AllFonts = (Get-Item -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts").Property
$AllFiles = Get-childitem C:\windows\fonts
$FilesFound = $true
$RegistryFound = $true
#Check if each of the files exist and set $FilesFound to false if any are missing.
Foreach ($file in $fileItems) {
    If  (($AllFiles.Name -contains $file) -eq $false) {
        $FilesFound = $false
    }
}
#Check if each of the registry values exist and set $RegistryFound to false if any are missing.
Foreach ($reg in $registryItems) {
    If (($AllFonts -contains $reg) -eq $false) {
        $RegistryFound = $false
    }
}
If($FilesFound -and $RegistryFound) {
    Write-Host "Detected!"
    exit 0
}
else {
    exit 1
}