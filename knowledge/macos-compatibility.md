# macOS Compatibility

Per-version Time Machine behavior, breakage history, and agent notes.

---

## Quick Reference Matrix

| macOS | Version | TM over AFP | TM over SMB (native) | TM over SMB (sparsebundle) | Notable Changes |
|-------|---------|------------|---------------------|--------------------------|----------------|
| High Sierra | 10.13 | ✅ | ❌ | ✅ | APFS introduced; TM still uses HFS+ |
| Mojave | 10.14 | ✅ | ❌ | ✅ | — |
| Catalina | 10.15 | ✅ | ❌ | ✅ | System/data volume split |
| Big Sur | 11 | ⚠️ Deprecated | ❌ | ✅ | AFP begins degradation; SMB sparsebundle reliable |
| Monterey | 12 | ❌ Broken | ❌ Broken | ✅ | SMB TM native intentionally removed by Apple; use sparsebundle |
| Ventura | 13 | ❌ | ✅ (Samba-fruit only) | ✅ | SMB TM native restored for proper Samba targets |
| Sonoma | 14 | ❌ | ✅ (Samba-fruit only) | ✅ | — |
| Sequoia | 15 | ❌ | ✅ (Samba-fruit only) | ✅ | Stricter Full Disk Access enforcement for tmutil |
| Tahoe | 16 | ❌ | ✅ (Samba-fruit only) | ✅ | — |

---

## Per-Version Agent Notes

### macOS 12 Monterey (most common "broken" case)
- Apple **intentionally disabled** native SMB Time Machine in Monterey
- `tmutil setdestination -ap smb://...` always returns error 45
- **The only working network path is the sparsebundle hack**
- The `TMShowUnsupportedNetworkVolumes` defaults key is still honored

### macOS 13+ Ventura and later
- Native SMB TM works again, but ONLY if destination has `fruit` VFS enabled
- Windows SMB shares still fail (error 45) — use sparsebundle
- `tmutil` requires Full Disk Access for the calling process (Sequoia+)

### macOS 11 Big Sur
- AFP is technically present but Apple treats it as deprecated
- SMB sparsebundle is the stable path
- System volume is read-only and excluded from TM by default (correct behavior)

### macOS 10.14 and earlier
- AFP over AirPort/Time Capsule is primary path
- SMB sparsebundle works but AirPort-style is preferred if hardware exists

---

## Full Disk Access Requirements (macOS 12+)

`sudo tmutil setdestination` requires the _calling application_ to have Full Disk Access, not just the terminal user.

| Calling context | How to grant |
|----------------|-------------|
| Terminal.app | System Settings → Privacy & Security → Full Disk Access → + → Terminal |
| VS Code Stable | Add `/Applications/Visual Studio Code.app` |
| VS Code Insiders | Add `/Applications/Visual Studio Code - Insiders.app` |
| Script run via launchd | Grant to the launchd agent's parent process (usually Fine — root runs with FDA) |

---

## Hardware UUID Requirement

Time Machine embeds the machine's Hardware UUID in the sparsebundle filename:
`<ComputerName>_<HardwareUUID>.sparsebundle`

- If the computer is renamed AFTER the sparsebundle is created, TM will not find the backup (it will create a new one)
- If migrating a backup to a new Mac, the UUID will differ — use `tmutil inheritbackup` to re-associate
- Get UUID: `system_profiler SPHardwareDataType | awk '/Hardware UUID/{print $3}'`

---

## M1/M2/M3/M4 (Apple Silicon) Notes

- All script commands work identically on Apple Silicon
- Rosetta 2 is not involved — TM is a system-level tool
- If the Mac was migrated from Intel, it retains its UUID from Migration Assistant
- ARM64 Macs have identical TM behavior to Intel from macOS 12 onward

---

## Pre-Upgrade Backup Checklist

Before upgrading macOS (especially across 2+ versions):
1. `tmutil status` — confirm last backup succeeded
2. `tmutil latestbackup` — note the path/timestamp
3. If using sparsebundle: `hdiutil verify /Volumes/<share>/<name>.sparsebundle`
4. Confirm enough space: post-upgrade macOS is typically 5–15 GB larger
5. Consider a second backup to USB before in-place upgrade

---

## Migrating Backups Between Destinations

```bash
# Re-associate an existing backup with the current machine
sudo tmutil inheritbackup /Volumes/<OldDest>/<ComputerName>.sparsebundle

# Associate a specific backup with this Mac
sudo tmutil associatedisk [-a] mount_point volume_backup_path
```
