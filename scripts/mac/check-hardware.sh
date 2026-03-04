#!/usr/bin/env bash
# scripts/mac/check-hardware.sh
# Prints hardware profile needed for Time Machine sizing and sparsebundle naming.
# No arguments required. All values are auto-detected.
# Output is human-readable and machine-parseable (KEY=value lines follow the header).

set -euo pipefail

OS_VERSION=$(sw_vers -productVersion)
OS_MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
COMPUTER=$(scutil --get ComputerName)
UUID=$(system_profiler SPHardwareDataType | awk '/Hardware UUID/{print $3}')
MODEL=$(system_profiler SPHardwareDataType | awk -F': ' '/Model Name/{print $2; exit}')
CHIP=$(system_profiler SPHardwareDataType | awk -F': ' '/Chip|Processor Name/{print $2; exit}')
MEMORY=$(system_profiler SPHardwareDataType | awk -F': ' '/Memory/{print $2; exit}')
DRIVE_BYTES=$(df / | awk 'NR==2{print $2 * 512}')
DRIVE_GB=$(( DRIVE_BYTES / 1024 / 1024 / 1024 ))
FREE_BYTES=$(df / | awk 'NR==2{print $4 * 512}')
FREE_GB=$(( FREE_BYTES / 1024 / 1024 / 1024 ))
SPARSEBUNDLE_NAME="${COMPUTER}_${UUID}.sparsebundle"

# Recommended sparsebundle size (3x drive, rounded up to nearest 100GB)
RECOMMENDED_RAW=$(( DRIVE_GB * 3 ))
RECOMMENDED_SIZE=$(( (RECOMMENDED_RAW + 99) / 100 * 100 ))

echo "╔══════════════════════════════════════════════╗"
echo "║       Time Machine Hardware Profile          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Computer Name : $COMPUTER"
echo "  Model         : $MODEL"
echo "  Chip          : $CHIP"
echo "  RAM           : $MEMORY"
echo "  macOS         : $OS_VERSION (major: $OS_MAJOR)"
echo "  Hardware UUID : $UUID"
echo "  Drive Size    : ~${DRIVE_GB} GB"
echo "  Free Space    : ~${FREE_GB} GB"
echo ""
echo "  Sparsebundle name   : $SPARSEBUNDLE_NAME"
echo "  Recommended TM cap  : ${RECOMMENDED_SIZE}g  (3x drive)"
echo "  Minimum TM cap      : $(( DRIVE_GB * 2 ))g  (2x drive)"
echo ""

# Network TM compatibility
echo "  Network TM Compatibility:"
if [ "$OS_MAJOR" -ge 13 ]; then
    echo "    ✅ Native TM: works with Samba + fruit VFS (Synology, TrueNAS, Linux)"
    echo "    ❌ Native TM: does NOT work with plain Windows SMB"
    echo "    ✅ Sparsebundle hack: works with plain Windows SMB"
elif [ "$OS_MAJOR" -eq 12 ]; then
    echo "    ❌ Native TM over network: BROKEN in Monterey (Apple removed it)"
    echo "    ✅ Sparsebundle hack: required for ALL network destinations"
else
    echo "    ✅ AFP: works (legacy)"
    echo "    ✅ Sparsebundle hack: works with all network destinations"
fi

echo ""
echo "  Full Disk Access required for tmutil:"
echo "    Grant to this process's parent app in:"
echo "    System Settings → Privacy & Security → Full Disk Access"
echo ""

# Machine-parseable block for agent consumption
echo "---"
echo "COMPUTER_NAME=$COMPUTER"
echo "HARDWARE_UUID=$UUID"
echo "MACOS_VERSION=$OS_VERSION"
echo "MACOS_MAJOR=$OS_MAJOR"
echo "DRIVE_GB=$DRIVE_GB"
echo "FREE_GB=$FREE_GB"
echo "RECOMMENDED_SPARSEBUNDLE_GB=$RECOMMENDED_SIZE"
echo "SPARSEBUNDLE_NAME=$SPARSEBUNDLE_NAME"
