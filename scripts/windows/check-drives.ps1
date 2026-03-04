# scripts/windows/check-drives.ps1
# Lists all drives with capacity info to help size Time Machine sparsebundles.
# Run as any user (no admin required).
# Usage: powershell -ExecutionPolicy Bypass -File check-drives.ps1

Write-Host ""
Write-Host "=== AO_TimeMachine: Windows Drive Inventory ===" -ForegroundColor Cyan
Write-Host ""

# All logical drives with size info
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -ne $null }

Write-Host ("  {0,-8} {1,-30} {2,12} {3,12} {4,12} {5,8}" -f `
    "Drive", "Label", "Total (GB)", "Used (GB)", "Free (GB)", "Free %")
Write-Host ("  " + "-" * 85)

foreach ($d in $drives) {
    try {
        $root = $d.Root
        $info = [System.IO.DriveInfo]::new($root)
        if ($info.IsReady) {
            $total = [math]::Round($info.TotalSize / 1GB, 1)
            $free  = [math]::Round($info.AvailableFreeSpace / 1GB, 1)
            $used  = [math]::Round(($info.TotalSize - $info.AvailableFreeSpace) / 1GB, 1)
            $pct   = [math]::Round(($info.AvailableFreeSpace / $info.TotalSize) * 100, 0)
            $label = $info.VolumeLabel
            if ([string]::IsNullOrEmpty($label)) { $label = "(no label)" }
            Write-Host ("  {0,-8} {1,-30} {2,12} {3,12} {4,12} {5,7}%" -f `
                $root, $label, $total, $used, $free, $pct)
        }
    } catch {
        # Skip drives that error (CD drives, etc.)
    }
}

Write-Host ""
Write-Host "=== Sizing Recommendations ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  For each Mac you want to back up, reserve the following on a destination drive:"
Write-Host ""
Write-Host ("  {0,-15} {1,15} {2,15}" -f "Mac Drive Size", "Min Cap (2x)", "Recommended (3x)")
Write-Host ("  " + "-" * 48)
@(128, 256, 512, 1024, 2048) | ForEach-Object {
    $drive = $_
    $min = $drive * 2
    $rec = $drive * 3
    Write-Host ("  {0,-15} {1,13} GB {2,13} GB" -f "${drive} GB", $min, $rec)
}

Write-Host ""
Write-Host "  Multiple Macs on one volume: sum their caps + 20% headroom"
Write-Host ""

# RAID / Storage Spaces detection
$pools = Get-StoragePool -IsPrimordial $false -ErrorAction SilentlyContinue
if ($pools) {
    Write-Host "=== Storage Pools (RAID / Storage Spaces) ===" -ForegroundColor Cyan
    foreach ($pool in $pools) {
        $vDisks = Get-VirtualDisk -StoragePool $pool -ErrorAction SilentlyContinue
        Write-Host ("  Pool: {0}  ({1} GB total)" -f $pool.FriendlyName, [math]::Round($pool.Size / 1GB, 1))
        foreach ($vd in $vDisks) {
            Write-Host ("    VDisk: {0}  ResiliencyLevel: {1}" -f $vd.FriendlyName, $vd.ResiliencySettingName)
        }
    }
    Write-Host ""
}

Write-Host "Run scripts/windows/create-share.ps1 to create an SMB share for Time Machine." -ForegroundColor Green
Write-Host ""
