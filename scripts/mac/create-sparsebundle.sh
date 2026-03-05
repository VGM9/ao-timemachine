#!/usr/bin/env bash
# scripts/mac/create-sparsebundle.sh
# Interactive: gathers share info and sparsebundle sizing, then:
#   1. Creates sparsebundle in /tmp
#   2. Copies it to the mounted SMB share
#   3. Attaches it
#   4. Outputs the mounted volume path (used by set-tm-destination)
#
# Usage: bash scripts/mac/create-sparsebundle.sh
#   Or non-interactively:
#     SHARE_VOLUME=/Volumes/MySMBShare SIZE=2t bash scripts/mac/create-sparsebundle.sh

set -euo pipefail

COMPUTER=$(scutil --get ComputerName)
UUID=$(system_profiler SPHardwareDataType | awk '/Hardware UUID/{print $3}')
BUNDLE_NAME="${COMPUTER}_${UUID}.sparsebundle"

echo "=== AO_TimeMachine: Create Sparsebundle ==="
echo "  Machine : $COMPUTER"
echo "  UUID    : $UUID"
echo "  Bundle  : $BUNDLE_NAME"
echo ""

# --- Gather inputs ---

if [ -z "${SHARE_VOLUME:-}" ]; then
    # Auto-detect mounted SMB shares so the user sees their own paths, not an example
    MOUNTED_SMB=$(mount | awk '$5 == "smbfs" {print $3}' 2>/dev/null)
    if [ -n "$MOUNTED_SMB" ]; then
        echo "Detected mounted SMB shares:"
        echo "$MOUNTED_SMB" | nl -w2 -s') '
        echo ""
        echo "Enter the share path (copy from above, or type a custom path):"
    else
        echo "No SMB shares detected. Mount first:"
        echo "  Finder → Go → Connect to Server → smb://<HOST>/<SHARE>"
        echo "Then enter the full mount path (e.g. /Volumes/YourShareName):"
    fi
    read -r SHARE_VOLUME
fi

if [ ! -d "$SHARE_VOLUME" ]; then
    echo "ERROR: $SHARE_VOLUME is not mounted."
    echo "Mount it first: open Finder → Go → Connect to Server → smb://<HOST>/<SHARE>"
    exit 1
fi

if [ -z "${SIZE:-}" ]; then
    DRIVE_GB=$(df / | awk 'NR==2{print $2 * 512 / 1024 / 1024 / 1024}' | cut -d. -f1)
    SUGGESTED=$(( (DRIVE_GB * 3 + 99) / 100 * 100 ))
    echo "Suggested sparsebundle size: ${SUGGESTED}g  (3x your ${DRIVE_GB}GB drive)"
    echo "Enter size (e.g. ${SUGGESTED}g, 1t, 500g) or press Enter to use ${SUGGESTED}g:"
    read -r SIZE
    SIZE="${SIZE:-${SUGGESTED}g}"
fi

TMP_BUNDLE="/tmp/${BUNDLE_NAME}"
DEST_BUNDLE="${SHARE_VOLUME}/${BUNDLE_NAME}"
VOLUME_NAME="Time Machine"

echo ""
echo "Creating sparsebundle: $TMP_BUNDLE (cap: $SIZE)"
hdiutil create \
    -size "$SIZE" \
    -type SPARSEBUNDLE \
    -fs "HFS+J" \
    -volname "$VOLUME_NAME" \
    -imagekey sparse-band-size=131072 \
    "$TMP_BUNDLE"

echo "Copying to $SHARE_VOLUME ..."
cp -r "$TMP_BUNDLE" "$DEST_BUNDLE"
echo "Copy complete. Removing temp copy..."
rm -rf "$TMP_BUNDLE"

echo ""
echo "Attaching sparsebundle from share..."
hdiutil attach "$DEST_BUNDLE" -nobrowse

MOUNTED_VOLUME="/Volumes/${VOLUME_NAME}"
if [ ! -d "$MOUNTED_VOLUME" ]; then
    echo "ERROR: sparsebundle did not mount at $MOUNTED_VOLUME"
    exit 1
fi

echo ""
echo "✅ Sparsebundle ready."
echo "   Share         : $SHARE_VOLUME"
echo "   Bundle        : $DEST_BUNDLE"
echo "   Mounted vol   : $MOUNTED_VOLUME"
echo ""
echo "Next step — set Time Machine destination (requires Full Disk Access):"
echo "  sudo tmutil setdestination \"$MOUNTED_VOLUME\""
echo ""
echo "Or run: bash scripts/mac/install-launchagent.sh"
