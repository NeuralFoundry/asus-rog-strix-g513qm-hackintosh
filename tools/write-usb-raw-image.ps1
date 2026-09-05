# Writes a raw disk image to a USB stick (what balenaEtcher does). Run as ADMINISTRATOR.
# Usage: .\write-usb-raw-image.ps1 -Image "F:\installer_usb.raw" -Disk 2
param([Parameter(Mandatory=$true)][string]$Image, [Parameter(Mandatory=$true)][int]$Disk)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Image)) { throw "Image not found: $Image" }
$d = Get-Disk -Number $Disk
if ($d.BusType -ne "USB") { throw "Disk $Disk is not USB ($($d.BusType)) - WRONG DISK, aborting" }
if ($d.Size -gt 256GB)    { throw "Disk $Disk is $([math]::Round($d.Size/1GB)) GB - too large for a USB stick, aborting for safety" }
$len = (Get-Item $Image).Length
if ($len -gt $d.Size) { throw "Image ($len bytes) is larger than the disk" }
Write-Host ("TARGET: Disk {0}: {1} {2} GB  <-  {3} ({4:N1} GB). Ctrl+C within 8 s to cancel." -f $d.Number, $d.FriendlyName, [math]::Round($d.Size/1GB), $Image, ($len/1GB))
Start-Sleep -Seconds 8
Get-Partition -DiskNumber $Disk -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-PartitionAccessPath -DiskNumber $Disk -PartitionNumber $_.PartitionNumber -AccessPath ($_.DriveLetter + ":") -ErrorAction SilentlyContinue } catch {} }
Clear-Disk -Number $Disk -RemoveData -RemoveOEM -Confirm:$false
Set-Disk -Number $Disk -IsOffline $true -ErrorAction SilentlyContinue
$dst = New-Object System.IO.FileStream("\\.\PhysicalDrive$Disk", [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 1MB, [System.IO.FileOptions]::WriteThrough)
$src = [System.IO.File]::OpenRead($Image)
$buf = New-Object byte[] (4MB); $done = 0L; $t0 = Get-Date; $lastPct = -1
try {
  while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
    if ($n % 512 -ne 0) { $pad = 512 - ($n % 512); for ($i = 0; $i -lt $pad; $i++) { $buf[$n + $i] = 0 }; $n += $pad }
    $dst.Write($buf, 0, $n); $done += $n
    $pct = [int](100 * $done / $len)
    if ($pct -ne $lastPct -and $pct % 5 -eq 0) { $sp = $done / 1MB / ((Get-Date) - $t0).TotalSeconds; Write-Host ("{0,3}%  {1:N0} MB  {2:N1} MB/s" -f $pct, ($done/1MB), $sp); $lastPct = $pct }
  }
  $dst.Flush()
} finally { $dst.Dispose(); $src.Dispose() }
Set-Disk -Number $Disk -IsOffline $false -ErrorAction SilentlyContinue
Update-Disk -Number $Disk -ErrorAction SilentlyContinue
Write-Host ("DONE: {0:N0} MB written in {1:N0} s" -f ($done/1MB), (((Get-Date) - $t0).TotalSeconds))
Get-Partition -DiskNumber $Disk -ErrorAction SilentlyContinue | Select-Object PartitionNumber, @{n="GB";e={[math]::Round($_.Size/1GB,2)}}, Type, DriveLetter | Format-Table -AutoSize
