# Time Machine Phase Space

Full decision tree for every Time Machine scenario. Read this before advising any user.

---

## Entry Point Detection

```
What platform are you on?
├── Mac (setting up a backup) → [Mac Client Flow]
├── Windows (becoming a destination) → [Windows Destination Flow]
└── Linux/NAS (becoming a destination) → [Linux/NAS Destination Flow]
```

---

## Mac Client Flow

### Step 1: Detect macOS version

```bash
sw_vers -productVersion
```

| Version | Major | TM Network Behavior |
|---------|-------|---------------------|
| ≤ 10.15 Catalina | ≤10 | AFP preferred; SMB sparsebundle works |
| 11 Big Sur | 11 | AFP deprecated; SMB sparsebundle reliable |
| 12 Monterey | 12 | Native SMB TM **broken**; sparsebundle required for all network |
| 13 Ventura | 13 | Native SMB TM restored (Samba-fruit only); Windows still needs sparsebundle |
| 14 Sonoma | 14 | Same as 13 |
| 15 Sequoia | 15 | Same as 13; tighter FDA enforcement |
| 16 Tahoe | 16 | Same as 15 |

### Step 2: What destination is available?

```
Destination type?
├── USB drive directly attached
│   └── → [USB Path] — always works, no further decisions
│
├── Windows PC on LAN
│   ├── Plain Windows SMB (no WSL2)
│   │   └── → [Sparsebundle Hack Path] — all macOS versions
│   └── Windows + WSL2 Samba with fruit VFS
│       ├── macOS ≤ 12 → ⚠️ unreliable (WSL2 NAT blocks port 445 to LAN)
│       └── macOS ≥ 13 → ✅ [Native TM Path]
│
├── Linux machine / self-hosted NAS
│   ├── Samba with fruit VFS configured → ✅ [Native TM Path]
│   └── Plain Samba (no fruit) → → [Sparsebundle Hack Path]
│
├── NAS appliance (Synology / QNAP / TrueNAS)
│   ├── Time Machine option enabled in GUI → ✅ [Native TM Path]
│   └── TM option NOT enabled → → [Sparsebundle Hack Path]
│
├── Another Mac
│   └── → [Mac-to-Mac TM Path]
│
└── Time Capsule (discontinued hardware)
    └── → [Native TM Path] — works until hardware fails
```

---

## Path: Sparsebundle Hack

Used when destination is Windows SMB (plain), plain Samba, or any unsupported network share.

### Prerequisite check
- [ ] SMB share is mounted in Finder or via `osascript -e 'mount volume "smb://HOST/SHARE"'`
- [ ] Credentials saved in Keychain (otherwise LaunchAgent can't mount at login)
- [ ] Full Disk Access granted to Terminal.app or VS Code for `tmutil`

### Step-by-step
```
1. Get machine name and hardware UUID
   → scripts/mac/check-hardware.sh

2. Calculate sparsebundle size
   → Mac drive size × 2 (min) to × 4 (recommended)
   → See sizing table in knowledge/destination-types.md

3. Create sparsebundle
   → hdiutil create -size <N>g -type SPARSEBUNDLE -fs "HFS+J"
      -volname "Time Machine"
      -imagekey sparse-band-size=131072
      "/tmp/<ComputerName>_<UUID>.sparsebundle"
   → scripts/mac/create-sparsebundle.sh

4. Copy sparsebundle to share
   → cp -r /tmp/<name>.sparsebundle /Volumes/<ShareName>/

5. Attach sparsebundle
   → hdiutil attach /Volumes/<ShareName>/<name>.sparsebundle
   → Mounts as /Volumes/Time Machine

6. Set TM destination
   → sudo tmutil setdestination "/Volumes/Time Machine"
   → Requires Full Disk Access

7. Verify destination
   → tmutil destinationinfo

8. Start first backup
   → sudo tmutil startbackup

9. Install auto-mount LaunchAgent
   → scripts/mac/install-launchagent.sh
   → Required: without this, sparsebundle won't remount after reboot
```

### Key constraint: sparsebundle filename
Time Machine enforces: `<ComputerName>_<HardwareUUID>.sparsebundle`
Get both values from `scripts/mac/check-hardware.sh`. If the Mac is renamed AFTER creating the sparsebundle, TM will not find it.

---

## Path: Native TM (Samba-fruit / USB / NAS)

Used when destination natively advertises TM support.

```
1. Verify destination appears in TM picker
   → System Settings → General → Time Machine → Add Backup Disk
   → If not visible: sudo defaults write com.apple.systempreferences
     TMShowUnsupportedNetworkVolumes 1

2. Set destination via tmutil
   → sudo tmutil setdestination -ap smb://USER@HOST/SHARE
   → or select from GUI

3. Verify
   → tmutil destinationinfo

4. Start backup
   → sudo tmutil startbackup
```

No LaunchAgent required — macOS manages remounting native TM destinations automatically.

---

## Path: USB Drive

```
1. Format drive (if needed)
   → diskutil eraseDisk APFS "Time Machine" /dev/diskN
   → (APFS on macOS 12+; HFS+ for older or if multiple Macs share drive)

2. Set destination
   → sudo tmutil setdestination /Volumes/"Time Machine"

3. (Optional) Exclude large non-essential paths
   → sudo tmutil addexclusion ~/Library/Caches
   → sudo tmutil addexclusion /path/to/VMs
```

---

## Path: Mac-to-Mac TM

```
1. On the destination Mac:
   → System Settings → General → Sharing → File Sharing → ON
   → Options → Share files and folders using SMB → ON

2. On the client Mac:
   → sudo tmutil setdestination -ap smb://USER@HOSTNAME/ShareName
```

---

## Windows Destination Flow

```
1. Inventory available drives
   → scripts/windows/check-drives.ps1
   → Output: drive letter, label, total size, free space

2. Decide: plain SMB or WSL2 Samba?
   ├── Plain SMB (easier, always works with sparsebundle hack):
   │   → scripts/windows/create-share.ps1
   │   → Params: drive path, share name, Windows username
   │
   └── WSL2 Samba with fruit VFS (enables native TM for macOS ≥ 13):
       → scripts/windows/wsl-samba-setup.sh (run inside WSL2)
       ⚠️  WSL2 NAT note: Windows Firewall must forward port 445
           from LAN interface to WSL2's virtual IP
           → netsh interface portproxy add v4tov4 listenaddress=0.0.0.0
             listenport=445 connectaddress=<WSL2_IP> connectport=445
       ⚠️  If another Windows service is using port 445 (LanmanServer):
           → Disable: sc config LanmanServer start= disabled && net stop LanmanServer
           (This will break normal Windows file sharing — not suitable for all setups)

3. Validate from Mac side
   → open Finder → Go → Connect to Server → smb://<WINDOWS_HOST>/<SHARE_NAME>
   → Verify credentials work and share is writable
```

---

## Sizing Decisions

| Mac drive size | Min cap (2×) | Recommended cap (4×) | Notes |
|---------------|-------------|---------------------|-------|
| 128 GB | 256 GB | 512 GB | |
| 256 GB | 512 GB | 1 TB | |
| 512 GB | 1 TB | 2 TB | |
| 1 TB | 2 TB | 4 TB | |
| 2 TB | 4 TB | 8 TB | |
| 4 TB | 8 TB | 16 TB | Consider USB at this scale |

For multiple Macs sharing one destination volume: sum their caps and ensure the destination has that much free space plus 20% headroom.

---

## LaunchAgent: When Required vs Not

| Destination type | LaunchAgent needed? |
|-----------------|---------------------|
| USB drive | No — macOS auto-mounts |
| Native TM (NAS/Samba-fruit/Time Capsule) | No — macOS reconnects automatically |
| Sparsebundle on SMB share | **Yes** — both the SMB mount AND the sparsebundle attach must be scripted |
| Sparsebundle on locally attached drive | No — drive auto-mounts |

LaunchAgent should:
1. Wait for network (ping destination host, retry up to 2 minutes)
2. Mount the SMB share via `osascript` (uses Keychain credentials)
3. Attach the sparsebundle via `hdiutil attach`
4. Log all outcomes to `~/Library/Logs/`

---

## Common Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `error 45` from `tmutil setdestination` | Destination doesn't support TM | Use sparsebundle path |
| `error -50` from `tmutil setdestination` | No username in SMB URL | Add `user@` to URL |
| `error 80` from `tmutil` | Missing Full Disk Access | Grant FDA in Security & Privacy |
| TM says "backup disk unavailable" | Sparsebundle not mounted | Check LaunchAgent log, remount manually |
| First backup hangs at "Preparing" | TM scanning exclusions | Wait; may take 30–60 min on first run |
| Backup fails after wake from sleep | SMB session expired | LaunchAgent should handle remount; check log |
| Sparsebundle grows to cap and never prunes | Cap too small | Increase cap: `hdiutil resize -size <new> <path>.sparsebundle` |
| "Time Machine completed a verification" then failure | Sparsebundle has errors | Run `hdiutil verify` then `hdiutil repair` |
