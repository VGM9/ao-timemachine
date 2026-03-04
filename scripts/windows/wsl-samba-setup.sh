#!/usr/bin/env bash
# scripts/windows/wsl-samba-setup.sh
# Configures Samba with Apple 'fruit' VFS extension inside WSL2 on Windows.
# This makes the Windows machine a NATIVE Time Machine destination (no sparsebundle needed).
#
# PREREQUISITES:
#   - Windows 10/11 with WSL2 installed and Ubuntu (or Debian) as the WSL2 distro
#   - Run this script INSIDE WSL2, not in PowerShell or CMD
#   - Run as root or with sudo privileges inside WSL2
#
# TRADEOFFS vs plain SMB + sparsebundle:
#   PRO: Native TM support (macOS ≥ 13); no sparsebundle management
#   CON: Must disable Windows LanmanServer service (breaks normal Windows file sharing)
#        OR use netsh portproxy (fragile — WSL2 IP changes on restart)
#   CON: WSL2 must be running for TM to connect
#
# After this script: the Mac can point TM directly at smb://WINDOWSHOST/TimeMachineShare
# with NO sparsebundle required (macOS 13+).
#
# Usage: bash scripts/windows/wsl-samba-setup.sh

set -euo pipefail

if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "✅ Running inside WSL2"
else
    echo "ERROR: This script must run inside WSL2 on Windows."
    echo "Open Windows Terminal → your WSL2 distro → then run this script."
    exit 1
fi

WSL2_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=== AO_TimeMachine: WSL2 Samba with fruit VFS ==="
echo "  WSL2 IP : $WSL2_IP"
echo ""

# --- Inputs ---

if [ -z "${SHARE_PATH:-}" ]; then
    echo "Enter the Windows path to mount (e.g. /mnt/d/TimeMachine):"
    read -r SHARE_PATH
fi

if [ -z "${SHARE_NAME:-}" ]; then
    echo "Enter the SMB share name (e.g. TimeMachineShare):"
    read -r SHARE_NAME
fi

if [ -z "${SAMBA_USER:-}" ]; then
    echo "Enter the Samba username (must match the Windows user that will connect from Mac):"
    read -r SAMBA_USER
fi

if [ -z "${TM_QUOTA:-}" ]; then
    echo "Enter the Time Machine quota (e.g. 2T, 1T, 500G):"
    read -r TM_QUOTA
fi

mkdir -p "$SHARE_PATH"

# --- Install Samba ---

echo ""
echo "Installing Samba..."
sudo apt-get update -qq
sudo apt-get install -y samba samba-common-bin
echo "✅ Samba installed"

# --- Configure smb.conf ---

CONF_GLOBAL="
[global]
   workgroup = WORKGROUP
   server string = WSL2 Time Machine
   netbios name = $(hostname)
   security = user
   map to guest = bad user
   dns proxy = no

   # Apple interoperability
   vfs objects = catia fruit streams_xattr
   fruit:apeattrib = yes
   fruit:metadata = stream
   fruit:model = MacSamba
   fruit:posix_rename = yes
   fruit:veto_appledouble = no
   fruit:nfs_aces = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes

   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
"

CONF_SHARE="
[${SHARE_NAME}]
   path = ${SHARE_PATH}
   valid users = ${SAMBA_USER}
   read only = no
   browsable = yes
   create mask = 0644
   directory mask = 0755

   # Time Machine advertising
   fruit:time machine = yes
   fruit:time machine max size = ${TM_QUOTA}
"

sudo bash -c "cat > /etc/samba/smb.conf << 'SMBCONF'
${CONF_GLOBAL}
${CONF_SHARE}
SMBCONF"

echo "✅ smb.conf written"

# --- Create Samba user ---

echo ""
echo "Setting Samba password for user: $SAMBA_USER"
echo "(This is the password the Mac will use when connecting)"
sudo smbpasswd -a "$SAMBA_USER"

# --- Start Samba ---

sudo service smbd restart
sudo service nmbd restart 2>/dev/null || true
echo "✅ Samba started"

# --- WSL2 NAT workaround instructions ---

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  REQUIRED: Windows-side port forwarding (run in PowerShell  ║"
echo "║  as Administrator on Windows, NOT inside WSL2)               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  WSL2 IP: $WSL2_IP"
echo ""
echo "  Step 1 — Disable Windows own SMB server to free port 445:"
echo "    sc config LanmanServer start= disabled"
echo "    net stop LanmanServer"
echo "    ⚠️  This disables normal Windows file sharing!"
echo ""
echo "  Step 2 — Forward LAN port 445 to WSL2:"
echo "    netsh interface portproxy add v4tov4 \\"
echo "      listenaddress=0.0.0.0 listenport=445 \\"
echo "      connectaddress=${WSL2_IP} connectport=445"
echo ""
echo "  Step 3 — Firewall rule:"
echo "    netsh advfirewall firewall add rule name=\"WSL2 SMB\" dir=in \\"
echo "      action=allow protocol=TCP localport=445"
echo ""
echo "  Step 4 — Make port proxy survive WSL2 IP changes on restart:"
echo "    Create a scheduled task or startup script that re-runs step 2"
echo "    with the current WSL2 IP: wsl hostname -I | awk '{print \$1}'"
echo ""
echo "  After the above, test from Mac:"
echo "    open 'smb://$(hostname)/${SHARE_NAME}'"
echo "    sudo tmutil setdestination -ap 'smb://USER@$(hostname)/${SHARE_NAME}'"
echo ""
echo "✅ WSL2 Samba setup complete."
