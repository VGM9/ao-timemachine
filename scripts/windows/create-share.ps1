# scripts/windows/create-share.ps1
# Creates an SMB share for Time Machine sparsebundles with correct permissions.
# Must be run as Administrator.
# Usage: powershell -ExecutionPolicy Bypass -File create-share.ps1
#   Or non-interactively:
#     $env:TM_DRIVE="D:"; $env:TM_FOLDER="TimeMachine"; $env:TM_USER="victor"
#     powershell -ExecutionPolicy Bypass -File create-share.ps1

#Requires -RunAsAdministrator

Write-Host ""
Write-Host "=== AO_TimeMachine: Create Windows SMB Share ===" -ForegroundColor Cyan
Write-Host ""

# --- Gather inputs ---

if (-not $env:TM_DRIVE) {
    Write-Host "Enter the drive for the share (e.g. D:):" -ForegroundColor Yellow
    $TM_DRIVE = Read-Host
} else { $TM_DRIVE = $env:TM_DRIVE }

if (-not $env:TM_FOLDER) {
    Write-Host "Enter the folder name to create (e.g. IntelMBP_TimeMachine):" -ForegroundColor Yellow
    $TM_FOLDER = Read-Host
} else { $TM_FOLDER = $env:TM_FOLDER }

if (-not $env:TM_USER) {
    Write-Host "Enter the Windows username that will authenticate from the Mac:" -ForegroundColor Yellow
    $TM_USER = Read-Host
} else { $TM_USER = $env:TM_USER }

$FOLDER_PATH = Join-Path $TM_DRIVE $TM_FOLDER
$SHARE_NAME  = $TM_FOLDER

# --- Create folder ---

if (-not (Test-Path $FOLDER_PATH)) {
    New-Item -ItemType Directory -Path $FOLDER_PATH -Force | Out-Null
    Write-Host "✅ Created folder: $FOLDER_PATH" -ForegroundColor Green
} else {
    Write-Host "  Folder already exists: $FOLDER_PATH"
}

# --- Set NTFS permissions ---
# Owner and specified user get Full Control; remove inheritance for clean permissions

$acl = Get-Acl $FOLDER_PATH
$acl.SetAccessRuleProtection($true, $false)  # disable inheritance, clear inherited

# SYSTEM — full control
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Administrators — full control
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

# Target user — full control
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $TM_USER, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)

Set-Acl -Path $FOLDER_PATH -AclObject $acl
Write-Host "✅ NTFS permissions set for: $TM_USER, SYSTEM, Administrators" -ForegroundColor Green

# --- Create or update SMB share ---

$existingShare = Get-SmbShare -Name $SHARE_NAME -ErrorAction SilentlyContinue
if ($existingShare) {
    Write-Host "  Share '$SHARE_NAME' already exists — updating permissions"
    Remove-SmbShare -Name $SHARE_NAME -Force
}

New-SmbShare -Name $SHARE_NAME -Path $FOLDER_PATH -FullAccess $TM_USER, "Administrators" | Out-Null
Write-Host "✅ SMB share created: \\$(hostname)\$SHARE_NAME → $FOLDER_PATH" -ForegroundColor Green

# --- Firewall rule ---

$firewallRule = Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue
if ($firewallRule) {
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
    Write-Host "✅ Firewall: File and Printer Sharing rules enabled" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not find 'File and Printer Sharing' firewall group — check manually" -ForegroundColor Yellow
}

# --- Network discovery ---

netsh advfirewall firewall set rule group="network discovery" new enable=Yes | Out-Null
Write-Host "✅ Firewall: Network discovery enabled" -ForegroundColor Green

# --- Summary ---

Write-Host ""
Write-Host "=== Share Ready ===" -ForegroundColor Green
Write-Host ""
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.InterfaceAlias -notlike "*WSL*" } | Select-Object -First 1).IPAddress
Write-Host "  Share path : \\$(hostname)\$SHARE_NAME"
Write-Host "  By IP      : \\${ip}\$SHARE_NAME"
Write-Host "  SMB URL    : smb://$(hostname)/$SHARE_NAME"
Write-Host "  SMB URL IP : smb://${ip}/$SHARE_NAME"
Write-Host "  Auth user  : $TM_USER"
Write-Host ""
Write-Host "On the Mac, connect via Finder → Go → Connect to Server:" -ForegroundColor Yellow
Write-Host "  smb://$(hostname)/$SHARE_NAME"
Write-Host ""
Write-Host "Then run on the Mac:" -ForegroundColor Yellow
Write-Host "  bash scripts/mac/create-sparsebundle.sh"
Write-Host ""
Write-Host "NOTE: Plain Windows SMB does NOT natively support Time Machine." -ForegroundColor DarkYellow
Write-Host "      The Mac must use the sparsebundle hack (handled by create-sparsebundle.sh)." -ForegroundColor DarkYellow
Write-Host "      For native TM support, run: scripts/windows/wsl-samba-setup.sh (in WSL2)" -ForegroundColor DarkYellow
Write-Host ""
