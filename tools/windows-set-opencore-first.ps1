# Run in an ADMINISTRATOR PowerShell on the G513QM Windows install: adds the OpenCore on the Samsung EFI partition to the firmware boot order
# 1. sira olarak ekler (BIOS'a girmeden). Kullanim: .\g513_windows_boot_sirasi.ps1
$ErrorActionPreference = "Stop"
$samsung = Get-Disk | Where-Object { $_.FriendlyName -like "*970 EVO*" } | Select-Object -First 1
if (-not $samsung) { throw "Samsung 970 EVO bulunamadi" }
$esp = Get-Partition -DiskNumber $samsung.Number | Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" } | Select-Object -First 1
if (-not $esp) { throw "Samsung'da EFI bolumu yok" }
$L = "S"; Add-PartitionAccessPath -DiskNumber $samsung.Number -PartitionNumber $esp.PartitionNumber -AccessPath "${L}:\" -ErrorAction SilentlyContinue
if (-not (Test-Path "${L}:\EFI\OC\OpenCore.efi")) { throw "${L}:\EFI\OC\OpenCore.efi yok" }
$out = bcdedit /create /d "OpenCore (Samsung)" /application bootapp
$id = [regex]::Match($out, "\{[0-9a-f-]+\}").Value
if (-not $id) { throw "bcdedit create basarisiz: $out" }
bcdedit /set $id device "partition=${L}:" | Out-Null
bcdedit /set $id path "\EFI\OC\OpenCore.efi" | Out-Null
bcdedit /set "{fwbootmgr}" displayorder $id /addfirst | Out-Null
bcdedit /enum "{fwbootmgr}"
Remove-PartitionAccessPath -DiskNumber $samsung.Number -PartitionNumber $esp.PartitionNumber -AccessPath "${L}:\" -ErrorAction SilentlyContinue
Write-Host "TAMAM: bir sonraki acilista OpenCore menusu (macOS/Windows) gelir. Geri almak: bcdedit /delete $id"
