# Prepares a Smokeless UMAF (Universal AMD Form Browser) boot stick. Run as ADMINISTRATOR.
# Download UniversalAMDFormBrowser.zip from https://github.com/DavidS95/Smokeless_UMAF and extract it to -Src.
# Usage: .\write-umaf-usb.ps1 -Disk 2 -Src C:\path\to\extracted\zip
param([Parameter(Mandatory=$true)][int]$Disk, [Parameter(Mandatory=$true)][string]$Src)
$ErrorActionPreference = "Stop"
foreach ($f in "EFI\Boot\Bootx64.efi","DisplayEngine.efi","SetupBrowser.efi","UiApp.efi") { if (-not (Test-Path (Join-Path $Src $f))) { throw "missing: $f" } }
$d = Get-Disk -Number $Disk
if ($d.BusType -ne "USB") { throw "Disk $Disk is not USB ($($d.BusType))" }
if ($d.Size -gt 256GB) { throw "Disk $Disk is too large, aborting for safety" }
Write-Host ("WILL ERASE: Disk {0}: {1} {2} GB - Ctrl+C within 8 s to cancel" -f $d.Number, $d.FriendlyName, [math]::Round($d.Size/1GB))
Start-Sleep -Seconds 8
Clear-Disk -Number $Disk -RemoveData -RemoveOEM -Confirm:$false
Initialize-Disk -Number $Disk -PartitionStyle GPT
$p = New-Partition -DiskNumber $Disk -Size 1GB -AssignDriveLetter
Format-Volume -Partition $p -FileSystem FAT32 -NewFileSystemLabel "UMAF" -Confirm:$false | Out-Null
$L = ($p | Get-Partition).DriveLetter; $dst = "${L}:\"
New-Item -ItemType Directory -Force (Join-Path $dst "EFI\Boot") | Out-Null
Copy-Item (Join-Path $Src "EFI\Boot\Bootx64.efi") (Join-Path $dst "EFI\Boot\Bootx64.efi")
foreach ($f in "DisplayEngine.efi","SetupBrowser.efi","UiApp.efi") { Copy-Item (Join-Path $Src $f) (Join-Path $dst $f) }
Write-Host "READY: boot the stick (Esc -> UEFI: USB) -> Device Manager -> AMD CBS -> NBIO Common Options -> GFX Configuration"
