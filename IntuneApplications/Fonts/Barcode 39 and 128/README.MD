# Barcodes
## Install
`powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -file Barcode.ps1 -Mode Install`

Install behavior: System
Device restart behavior: No specific action
Operating system architecture: 32-bit & 64-bit
Minimum operating system: Windows 10 1607

## Detection

Rules format: Use a custom detection script
Script file: `Detection.ps1`

## Uninstall
`powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -file Barcode.ps1 -Mode Uninstall`
