# Assigns a temporary drive letter to the USB stick's EFI partition, runs the given Python edit script
# against it (the script receives the drive letter as its first argument), then removes the letter.
# Run as ADMINISTRATOR.  Usage: .\edit-usb-efi.ps1 -Script my-edit.py
param([Parameter(Mandatory=$true)][string]$Script)
$ErrorActionPreference = "Stop"
$d = Get-Disk | Where-Object BusType -eq USB | Select-Object -First 1
if (-not $d) { throw "No USB disk found" }
$p = Get-Partition -DiskNumber $d.Number -PartitionNumber 1
Write-Host ("USB disk {0} {1}; partition 1 is {2} MB, type {3}" -f $d.Number, $d.FriendlyName, [math]::Round($p.Size/1MB), $p.Type)
$L = "Q"; if (Get-Volume -DriveLetter $L -ErrorAction SilentlyContinue) { $L = "R" }
Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 1 -AccessPath "${L}:\"
Start-Sleep -Seconds 2
Get-ChildItem "${L}:\" | Select-Object Name | Format-Table -HideTableHeaders
& python (Join-Path $PSScriptRoot $Script) $L
Get-ChildItem "${L}:\" -Filter "opencore-*.txt" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem "${L}:\" -Filter "panic-*.txt" -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber 1 -AccessPath "${L}:\"
Write-Host "EFI edited, drive letter removed"
