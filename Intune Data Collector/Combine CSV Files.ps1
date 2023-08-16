$sourcefolder = ".\"
$sourcefiles = Get-ChildItem -Path $sourcefolder -Filter *.csv
$result = @()
foreach ($file in $sourcefiles) {
    $data = Import-Csv $file.FullName
    $result += $data
}
$result | Export-Csv ".\Intune Merged.csv" -NoTypeInformation
$result