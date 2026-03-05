# `@vgm9/ao-timemachine`

**Agent Of Time Machine** — an agentic subject matter expert (SME) zone for Mac Time Machine backup setup.

## If You Are an Agent Reading This Cold

You have no prior context. Here is what you need to know before taking any action:

1. **This is a generic, portable package.** It contains knowledge and runnable scripts — it does not contain any machine-specific state. Your live backup configuration lives in `~/Library/` on the Mac, not here.
2. **Read `knowledge/phase-space.md` first.** It contains the complete decision tree. Never guess compatibility — the matrix tells you exactly which path to take for any macOS × destination combination.
3. **Run `npm run inspect` before doing anything on a Mac client.** You need the macOS version and UUID before you can make any decisions.
4. **Plain Windows SMB does not natively support Time Machine on any macOS version.** Don't attempt `tmutil setdestination` directly against a Windows share — use the sparsebundle hack.
5. **The scripts have not been end-to-end tested on a real machine.** See the [Test Status](#test-status) section. `inspect` is safe. Anything that writes to disk deserves a dry-run review before you execute it.
6. **If a LaunchAgent already exists on the target machine**, do not run `npm run automount:install` without checking first — it will overwrite silently. See [Instance vs. Package](#instance-vs-package).
7. **`tmutil setdestination` requires Full Disk Access** granted to the calling application (Terminal.app or VS Code). If it fails with an access error, open System Settings → Privacy & Security → Full Disk Access before retrying.

---

## What is an AO_ Folder?

An **Agent Of** (AO_) folder is a portable, deployable knowledge + tooling zone that an AI agent can inhabit to operate as a domain expert. It contains:

- **Knowledge base** — the full phase space of the domain (all sub-cases, decision trees, compatibility matrices)
- **Runnable scripts** — every operation the agent may need to perform, as discrete shell/PowerShell scripts
- **npm scripts** — every operation mapped to a named command so agents and humans can trigger them consistently
- **VS Code customization files** — `copilot-instructions.md`, `.agent.md`, `SKILL.md` so any Copilot agent (Stable or Insiders) can invoke domain expertise automatically
- **Templates** — parameterized config/script files for generating system-specific artifacts

This concept predates Claude plugins and VS Code Skills — AO_ folders are a portable agentic knowledge package format for VS Code Copilot agents.

---

## Quick Start

### Prerequisites (Mac client)
- **macOS 10.15+** — all versions covered, behavior varies (see phase-space.md)
- **Full Disk Access** granted to Terminal.app (or VS Code) — required for `tmutil`
  → System Settings → Privacy & Security → Full Disk Access
- **SMB credentials saved in Keychain** — required for LaunchAgent auto-mount to work silently
  → Finder → Go → Connect to Server → `smb://HOST/SHARE` → check "Remember this password"

### On a Mac (setting up a Time Machine client)

```bash
git clone https://github.com/VGM9/ao-timemachine.git
cd ao-timemachine
npm run inspect               # hardware profile: macOS version, UUID, drive size, path recommendation
```

For Windows SMB destination (the most common case):
```bash
# 1. Mount the SMB share in Finder first: Go → Connect to Server → smb://HOST/SHARE
npm run sparsebundle:create   # creates a sized HFS+ sparsebundle and copies it to the share
npm run automount:install     # installs LaunchAgent to re-mount at login/wake
# 2. Manually: sudo tmutil setdestination /Volumes/Time\ Machine
npm run backup:start          # trigger first backup
```

Or use the interactive wizard which walks through the above:
```bash
npm run backup:configure      # interactive wizard — asks destination type, calls correct scripts
```

### On Windows (setting up a Time Machine destination)

```powershell
# In PowerShell as Administrator:
npm run windows:drives        # inventory drives and free space
npm run windows:share         # create and permission the SMB share
# optional — for native TM support via WSL2 Samba:
npm run windows:samba
```

---

## Domain Coverage (Phase Space)

See [`knowledge/phase-space.md`](knowledge/phase-space.md) for the full decision tree.

| Mac macOS | Windows SMB | Linux/NAS Samba (fruit) | USB |
|-----------|-------------|------------------------|-----|
| ≤ 12 Monterey | sparsebundle hack | native TM | native TM |
| 13+ Ventura/Sonoma/Sequoia/Tahoe | sparsebundle hack | native TM | native TM |

Destination types covered: USB, Windows SMB, Linux/Samba, TrueNAS, Synology, QNAP, another Mac, Time Capsule (legacy).

---

## npm Scripts Reference

| Script | Platform | What it does |
|--------|----------|--------------|
| `npm run inspect` | Mac | Detect macOS version, UUID, drive size, recommend path |
| `npm run backup:configure` | Mac | Interactive wizard — full sparsebundle → LaunchAgent flow |
| `npm run backup:start` | Mac | Start a Time Machine backup now (`sudo tmutil startbackup`) |
| `npm run backup:status` | Mac | Show TM destination, backup phase, last completed time |
| `npm run backup:diagnose` | Mac | Diagnostic pass — check destination, mount, LaunchAgent, last backup |
| `npm run sparsebundle:create` | Mac | Create a sized sparsebundle and copy it to the mounted SMB share |
| `npm run automount:install` | Mac | Install auto-mount LaunchAgent for network destinations |
| `npm run windows:drives` | Windows | List drives/free space for sizing |
| `npm run windows:share` | Windows | Create & configure an SMB share for TM |
| `npm run windows:samba` | Windows | Install Samba + fruit VFS in WSL2 for native TM support |

### CLI sub-command mapping

The Node CLI (`bin/ao-tm.js`) is the implementation layer for wizard and diagnostic flows:

| npm script | CLI command | Internal function |
|------------|-------------|-------------------|
| `npm run backup:configure` | `node bin/ao-tm.js setup` | `cmdSetup()` — interactive wizard |
| `npm run backup:diagnose` | `node bin/ao-tm.js diagnose` | `cmdDiagnose()` — 6-check diagnostic pass |
| `inspect` / `status` | `ao-tm check` / `ao-tm status` | `cmdCheck()` / `cmdStatus()` |

---

## VS Code Integration

When this repo is open in VS Code (Stable or Insiders), the `.github/agents/AO_TimeMachine.agent.md` agent is available in the agent picker as **Agent of Time Machine**.

The `.github/skills/ao-timemachine/SKILL.md` can be referenced from any other VS Code workspace to pull in TM domain expertise on demand.

---

## Test Status

Honest inventory of what has been validated vs. specified:

| Script / Command | Status | Notes |
|-----------------|--------|-------|
| `npm run inspect` | ✅ Smoke-tested | `check-hardware.sh` ran; output verified correct |
| `bin/ao-tm.js` (CLI dispatch) | ✅ Smoke-tested | `node bin/ao-tm.js check` ran successfully |
| `npm run backup:configure` | ❌ Not tested | Interactive wizard; `cmdSetup()` written but never invoked |
| `npm run backup:start` | ❌ Not tested | Wraps `sudo tmutil startbackup` — well-understood command, untested via npm |
| `npm run backup:status` | ❌ Not tested | `status.sh` written but never run |
| `npm run backup:diagnose` | ❌ Not tested | `cmdDiagnose()` written but never invoked |
| `npm run sparsebundle:create` | ❌ Not tested | Script written; sparsebundle exists but was created manually via direct `hdiutil` |
| `npm run automount:install` | ❌ Not tested | Script written; LaunchAgent on SEDLEC was installed manually; see [Instance vs. Package](#instance-vs-package) |
| `npm run windows:drives` | ❌ Not tested | Different machine required |
| `npm run windows:share` | ❌ Not tested | Different machine required |
| `npm run windows:samba` | ❌ Not tested | Different machine required |

**Before running untested scripts on a machine with an active backup**, read the script source, verify `SHARE_HOST` and `SHARE_NAME` env vars are correct, and keep a backup copy of any existing `~/Library/LaunchAgents/` plist.

---

## Instance vs. Package

This repo is **generic and portable** — no machine-specific values are stored here. Your live backup configuration is instance state that lives on the target machine:

| Artifact | Where it lives | How it got there |
|----------|---------------|-----------------|
| Sparsebundle | `<SHARE_VOLUME>/<COMPUTER>_<UUID>.sparsebundle` | Created by `sparsebundle:create` or manually |
| Mount script | `~/Library/Scripts/mount-timemachine.sh` | Generated by `automount:install` or written manually |
| LaunchAgent plist | `~/Library/LaunchAgents/com.<hostname>.timemachine-mount.plist` | Generated by `automount:install` or written manually |
| TM destination | System TM config (read via `tmutil destinationinfo`) | Set by `sudo tmutil setdestination` |

**If you already have a working setup:** check whether your LaunchAgent was installed manually before cloning this repo. If so, running `npm run automount:install` will overwrite it silently. Compare the existing plist against what the template would generate before proceeding.

**To check your existing state:**
```bash
tmutil destinationinfo          # current destination
launchctl list | grep timemachine
ls ~/Library/LaunchAgents/      # existing plists
cat ~/Library/LaunchAgents/com.*.timemachine-mount.plist  # review before overwriting
```

---

## Deployment to a New Machine

```bash
# Clone
git clone https://github.com/VGM9/ao-timemachine.git ~/AO_TimeMachine
cd ~/AO_TimeMachine

# No install step required — scripts use only built-in macOS/Windows tools
# Node CLI requires node >= 18 (no npm dependencies)

# Mac client setup
npm run inspect                 # hardware profile first
npm run backup:configure        # interactive wizard

# Windows destination setup (run in PowerShell as Admin)
npm run windows:drives
npm run windows:share
```

