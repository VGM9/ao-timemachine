#!/usr/bin/env bash
# scripts/mac/status.sh
# Shows current Time Machine status, destination info, and last backup time.

set -uo pipefail

echo "=== Time Machine Status ==="
echo ""

# Destination
echo "--- Destinations ---"
tmutil destinationinfo 2>&1 || echo "No destinations configured."
echo ""

# Current backup status
echo "--- Backup Status ---"
STATUS=$(tmutil status 2>&1)
echo "$STATUS"
echo ""

# Last backup
echo "--- Last Completed Backup ---"
LATEST=$(tmutil latestbackup 2>/dev/null || echo "(none)")
echo "$LATEST"
echo ""

# Sparsebundle state
echo "--- Network Volume State ---"
if mount | grep -q "Time Machine"; then
    echo "✅ /Volumes/Time Machine is mounted"
    df -h "/Volumes/Time Machine" | awk 'NR==2{printf "   Used: %s / %s (%s)\n", $3, $2, $5}'
else
    echo "⚠️  /Volumes/Time Machine is NOT mounted"
    echo "   Run: bash scripts/mac/install-launchagent.sh (or check ~/Library/Logs/timemachine-mount.log)"
fi

# LaunchAgent state
echo ""
echo "--- Auto-mount LaunchAgent ---"
AGENTS=$(ls ~/Library/LaunchAgents/*.timemachine-mount.plist 2>/dev/null)
if [ -n "$AGENTS" ]; then
    for PLIST in $AGENTS; do
        LABEL=$(basename "$PLIST" .plist)
        STATE=$(launchctl list "$LABEL" 2>/dev/null | awk '/PID/{print "running (PID "$2")"; found=1} END{if(!found) print "loaded, not running"}')
        echo "  $LABEL: $STATE"
    done
else
    echo "  ⚠️  No timemachine-mount LaunchAgent found"
    echo "  Run: bash scripts/mac/install-launchagent.sh"
fi

# Recent TM log events
echo ""
echo "--- Recent Time Machine Events (last 30 min) ---"
log show \
    --predicate 'subsystem == "com.apple.TimeMachine"' \
    --last 30m \
    --style compact \
    2>/dev/null | tail -20 || echo "(no log access — Full Disk Access may be needed)"

echo ""
echo "--- Mount Script Log ---"
LOG="$HOME/Library/Logs/timemachine-mount.log"
if [ -f "$LOG" ]; then
    tail -20 "$LOG"
else
    echo "(no mount log yet)"
fi
