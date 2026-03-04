---
name: ao-timemachine
description: "Avatar Of Time Machine — complete Mac Time Machine setup, diagnosis, and recovery across all destination types (USB, Windows SMB, Linux/NAS, Synology, TrueNAS). USE FOR: setting up TM on any Mac; configuring Windows/Linux as a TM destination; sizing sparsebundles; diagnosing backup failures; installing auto-mount LaunchAgents. Covers macOS Monterey through Tahoe. Reads a comprehensive phase-space knowledge base before acting."
---

# Skill: Avatar Of Time Machine

## What This Skill Does

Transforms the invoking agent into a Time Machine domain expert. Loads the full phase-space decision tree and all runnable scripts needed to guide a user through any TM scenario — client setup, destination setup, sizing, persistence, or diagnosis.

## When To Invoke

- User mentions Time Machine, TM backup, sparsebundle, or `tmutil`
- User wants to back up a Mac over a network
- User wants to configure a Windows PC, Linux machine, or NAS as a TM destination
- Backup is failing, hanging, or shows errors
- User is upgrading macOS and wants a pre-upgrade backup
- User is setting up a new Mac and wants to restore from TM

## The AO_ Concept

This skill is part of the **Avatar Of (AO_)** pattern: a portable agentic knowledge zone containing:
- A knowledge base (phase-space, compatibility matrix, destination types)
- Runnable scripts for every operation
- VS Code customization files (agent, prompts, instructions)
- npm scripts mapping human-readable names to every operation

If the `@vgm9/ao-timemachine` package is installed or the repo is cloned locally, all scripts and knowledge files are available on disk. If not, use the knowledge embedded in this skill file.

---

## Phase Space Summary

### The Core Problem
Time Machine over a network requires the destination to speak Apple's `afpd`/`netatalk` protocol, OR Samba with the `fruit` VFS module. Plain Windows SMB shares do **not** satisfy this requirement on any macOS version.

### Destination Compatibility Matrix

| Destination | macOS ≤ 12 | macOS 13+ | Notes |
|-------------|-----------|-----------|-------|
| USB drive | ✅ Native | ✅ Native | Always simplest |
| Windows SMB (plain) | ❌ Direct / ✅ Sparsebundle hack | ❌ Direct / ✅ Sparsebundle hack | Sparsebundle wraps HFS+ over SMB |
| Windows + WSL2 Samba (fruit VFS) | ⚠️ Unreliable | ✅ Native | WSL2 NAT complicates port 445 |
| Linux Samba with fruit VFS | ✅ Native | ✅ Native | Most reliable network option |
| Synology DSM / QNAP / TrueNAS | ✅ Native (enable in GUI) | ✅ Native | Best plug-and-play NAS option |
| Another Mac (Sharing prefs) | ✅ Native | ✅ Native | Requires macOS Sharing enabled |
| Time Capsule (discontinued) | ✅ Native | ✅ Native | Hardware EOL but still works |

### The Sparsebundle Hack (Windows → Mac)
When the destination is a plain Windows SMB share:
1. Create an HFS+ sparsebundle image locally (`hdiutil create -type SPARSEBUNDLE -fs "HFS+J"`)
2. Copy it to the mounted SMB share
3. Mount (attach) the sparsebundle locally (`hdiutil attach`)
4. Point `tmutil setdestination` at the mounted HFS+ volume (not the share)
5. Install a LaunchAgent to re-mount at login/wake

**Sparsebundle filename convention**: `<ComputerName>_<HardwareUUID>.sparsebundle`
This is required — Time Machine verifies the filename matches the machine.

### Sizing Rule
Sparsebundle cap = 2–4× the Mac's drive size.
Time Machine keeps: hourly backups for 24h, daily for 1 month, weekly after — versioning multiplies raw data by 3–5× before TM auto-prunes.

### Auto-Mount LaunchAgent
Network TM destinations must auto-mount on login/wake. Pattern:
1. Shell script: ping host → mount SMB → `hdiutil attach` sparsebundle
2. LaunchAgent plist: `RunAtLoad = true`, `StandardOutPath` to log file
3. Load: `launchctl load ~/Library/LaunchAgents/<label>.plist`
Templates at `templates/` in this package.

---

## macOS Version Notes

| Version | TM Behavior |
|---------|-------------|
| ≤ 10.15 Catalina | HFS+ sparsebundle, AFP preferred |
| 11 Big Sur | SMB+AFP deprecated; sparsebundle hack reliable |
| 12 Monterey | Native SMB TM broken; sparsebundle hack required for all network |
| 13 Ventura | Native SMB TM restored for Samba-fruit destinations; Windows still needs hack |
| 14 Sonoma | Same as Ventura |
| 15 Sequoia | Same as Ventura; tighter FDA requirements for tmutil |
| 16 Tahoe | Same as Sequoia |

### Full Disk Access Note (macOS 12+)
`tmutil setdestination` requires Full Disk Access granted to the calling application.
Grant to: `Terminal.app` (for interactive) or the parent VS Code app (for agent-driven).
Path: System Settings → Privacy & Security → Full Disk Access

---

## Script Quick Reference

Run from repo root or via `npx @vgm9/ao-timemachine <command>`:

```bash
# Mac client
npm run mac:check-hardware        # Print OS version, UUID, drive size
npm run mac:create-sparsebundle   # Interactive: size, host, share name → creates + copies image
npm run mac:install-launchagent   # Install auto-mount LaunchAgent
npm run mac:status                # tmutil status + last backup time

# Windows destination
npm run windows:check-drives       # List all drives with free space
npm run windows:create-share       # Create SMB share with correct permissions
npm run windows:wsl-samba          # (Advanced) Configure WSL2 Samba for native TM
```

---

## Diagnostic Checklist

If TM backups are missing/failing:
1. Is sparsebundle mounted? → `ls /Volumes/`; look for the volume named "Time Machine"
2. Is SMB share mounted? → `mount | grep smb` or check Finder sidebar
3. Is destination configured? → `tmutil destinationinfo`
4. Check LaunchAgent log → `cat ~/Library/Logs/timemachine-mount.log`
5. Check TM system log → `log show --predicate 'subsystem == "com.apple.TimeMachine"' --last 2h`
6. Is sparsebundle corrupted? → `hdiutil verify <path>.sparsebundle`
7. Is ADBEL (or destination host) reachable? → `ping <hostname>`
8. Full Disk Access still granted? → check System Settings → Privacy

## Recovery: Corrupted Sparsebundle
```bash
hdiutil verify /Volumes/<share>/<name>.sparsebundle
# If damaged:
hdiutil repair /Volumes/<share>/<name>.sparsebundle
# If unrepairable, start fresh:
# 1. Delete old sparsebundle
# 2. npm run mac:create-sparsebundle
# 3. npm run mac:install-launchagent (re-point TM destination)
```
