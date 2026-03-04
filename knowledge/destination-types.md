# Destination Types

Capabilities, limitations, and setup requirements for every Time Machine destination type.

---

## USB / Thunderbolt / FireWire Drive

**Native TM support**: Yes — always, all macOS versions
**Setup friction**: Minimal
**Reliability**: Highest (no network dependency)
**Limitations**: Must be physically attached; easily disconnected; single-machine use unless formatted HFS+ (not APFS) for multi-Mac sharing

**Filesystem recommendation**:
- Single Mac, macOS 10.15+: APFS
- Multiple Macs sharing one drive: HFS+ (APFS doesn't support multiple TM backups on one volume natively)

**Format command**:
```bash
diskutil eraseDisk APFS "Time Machine" /dev/diskN
# or for multi-Mac:
diskutil eraseDisk HFS+ "Time Machine" /dev/diskN
```

---

## Windows SMB Share (Plain)

**Native TM support**: No — on any macOS version
**Error when attempted directly**: `Disk does not support Time Machine backups. (error 45)`
**Workaround**: Sparsebundle hack (HFS+ image hosted on SMB share)
**Setup friction**: Medium
**Reliability**: Good — requires LaunchAgent for auto-mount

**Why it doesn't work directly**: Windows SMB does not implement the `AFP_AfpInfo` extended attributes that Time Machine requires to track backup state. Even on macOS ≥ 13, only Samba with the `fruit` VFS module emulates this correctly.

**What DOES work**: An HFS+ sparsebundle disk image stored on the SMB share. Time Machine talks to the locally-mounted HFS+ volume inside the image and never sees the Windows filesystem.

**Sizing**: sparsebundle cap at 2–4× Mac drive size
**Persistence**: LaunchAgent required (mount share + attach sparsebundle at login/wake)

---

## Windows + WSL2 Samba with fruit VFS

**Native TM support**: Yes for macOS ≥ 13 (if configured correctly)
**Setup friction**: High
**Reliability**: Moderate — WSL2 NAT complicates LAN exposure

**Core problem with WSL2**: WSL2 runs inside a Hyper-V virtual switch with its own private IP. Port 445 (SMB) on the Windows host goes to Windows LanmanServer, not WSL2. To expose WSL2 Samba to the LAN:
1. Disable Windows LanmanServer service (breaks normal Windows file sharing!)
2. OR: Use `netsh portproxy` to forward port 445 to WSL2 — fragile because WSL2 IP changes on restart

**When to recommend**: Only if user is technical AND wants native TM (no sparsebundle) AND doesn't use Windows file sharing for other purposes.

**Key Samba config options for fruit VFS**:
```ini
[TimeMachineShare]
  vfs objects = catia fruit streams_xattr
  fruit:time machine = yes
  fruit:time machine max size = 2T
  fruit:apeattrib = yes
```

---

## Linux Machine with Samba + fruit VFS

**Native TM support**: Yes — all macOS versions
**Setup friction**: Medium
**Reliability**: Excellent — most reliable network option

**Minimal Samba config** (`/etc/samba/smb.conf`):
```ini
[global]
  vfs objects = catia fruit streams_xattr
  fruit:apeattrib = yes
  fruit:metadata = stream

[TimeMachine]
  path = /path/to/backup/folder
  valid users = macuser
  read only = no
  browsable = yes
  fruit:time machine = yes
  fruit:time machine max size = 2T
```

**Required packages**: `samba`, `samba-vfs-modules` (or `samba-common-bin` depending on distro)

---

## Synology DSM

**Native TM support**: Yes
**Setup friction**: Low (GUI)
**Reliability**: Excellent

**Enable in GUI**: Control Panel → File Services → SMB → Advanced Settings → Enable Time Machine
OR: Control Panel → File Services → AFP → Enable AFP and Time Machine

**Per-shared-folder quota**: Set in Shared Folder → Edit → Advanced → Time Machine → quota = sparsebundle cap
**Multi-Mac**: Create one shared folder per Mac, set individual quotas

---

## QNAP QTS

**Native TM support**: Yes
**Setup friction**: Low (GUI)
**Enable**: Network & File Services → Win/Mac/NFS → Apple Networking → Enable Bonjour Time Machine advertisement

---

## TrueNAS SCALE

**Native TM support**: Yes
**Setup friction**: Low-medium
**Enable**: Datasets → Add Dataset (type: SMB) → Shares → Windows (SMB) Shares → Add → check "Time Machine"

---

## TrueNAS CORE (FreeBSD)

**Native TM support**: Yes (via Netatalk AFP or Samba-fruit)
**Enable Samba-fruit**: Services → SMB → Configure → Auxiliary Parameters:
```
vfs objects = fruit streams_xattr
fruit:apeattrib = yes
fruit:time machine = yes
```

---

## Another Mac (via Sharing preference)

**Native TM support**: Yes
**Setup friction**: Minimal
**Enable**: Destination Mac → System Settings → General → Sharing → File Sharing → ON
Then on client: `sudo tmutil setdestination -ap smb://user@hostname/Volume`

---

## Apple Time Capsule (discontinued)

**Native TM support**: Yes — purpose-built
**Status**: Discontinued 2018; no replacement parts; last firmware update 2017
**Risk**: Hardware failure unrecoverable; AirPort firmware not getting security updates
**Still works** if hardware is functional; treat as legacy

---

## Cloud / S3 / Backblaze B2

**Native TM support**: No — Time Machine has no cloud backend
**Alternatives**: 
- Arq Backup (paid, $50) — incremental, cloud-native, similar versioning model
- Duplicati (free) — less polished but functional
- rclone + sparsebundle — possible but fragile; not recommended

Time Machine is inherently a LAN-first, block-level backup tool. It is not designed for cloud.
