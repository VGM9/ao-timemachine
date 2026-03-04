# `@vgm9/ao-timemachine`

**Avatar Of Time Machine** — an agentic subject matter expert (SME) zone for Mac Time Machine backup setup.

## What is an AO_ folder?

An **Avatar Of** (AO_) folder is a portable, deployable knowledge + tooling zone that an AI agent can inhabit to operate as a domain expert. It contains:

- **Knowledge base** — the full phase space of the domain (all sub-cases, decision trees, compatibility matrices)
- **Runnable scripts** — every operation the agent may need to perform, as discrete shell/PowerShell scripts
- **npm scripts** — every operation mapped to a named command so agents and humans can trigger them consistently
- **VS Code customization files** — `copilot-instructions.md`, `.agent.md`, `SKILL.md` so any Copilot agent (Stable or Insiders) can invoke domain expertise automatically
- **Templates** — parameterized config/script files for generating system-specific artifacts

This concept predates Claude plugins and VS Code Skills — AO_ folders are the original portable agentic knowledge package format used in the `vgm9` cluster.

---

## Quick Start

### On a Mac (setting up a Time Machine client)

```bash
git clone https://github.com/vgm9/ao-timemachine.git
cd ao-timemachine
npm run inspect           # see your hardware profile and TM compatibility
npm run backup:configure  # interactive setup wizard
```

### On Windows (setting up a Time Machine destination)

```powershell
# In PowerShell as Administrator:
npm run windows:drives   # inventory drives and free space
npm run windows:share    # create and permission the SMB share
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
| `npm run check` | Mac | Detect macOS version, UUID, drive size, recommend destination type |
| `npm run setup` | Mac | Interactive wizard — full sparsebundle → LaunchAgent flow |
| `npm run status` | Mac | Show current TM status & last backup time |
| `npm run diagnose` | Mac | Diagnose why backups are failing |
| `npm run mac:check-hardware` | Mac | Print hardware profile for sizing decisions |
| `npm run mac:create-sparsebundle` | Mac | Create a sized sparsebundle on the destination share |
| `npm run mac:install-launchagent` | Mac | Install the auto-mount LaunchAgent |
| `npm run mac:status` | Mac | Current backup phase, percent, last completed |
| `npm run windows:check-drives` | Windows | List drives/free space for sizing |
| `npm run windows:create-share` | Windows | Create & configure an SMB share for TM |
| `npm run windows:wsl-samba` | Windows | Install Samba + fruit VFS in WSL2 for native TM support |

---

## VS Code Integration

When this repo is open in VS Code (Stable or Insiders), the `.github/agents/Avatar.agent.md` agent is available in the agent picker as **Avatar of Time Machine**.

The `.github/skills/ao-timemachine/SKILL.md` can be referenced from any other VS Code workspace to pull in TM domain expertise on demand.

---

## Deployment to a New Machine

```bash
# Clone
git clone https://github.com/vgm9/ao-timemachine.git ~/AO_TimeMachine
cd ~/AO_TimeMachine

# Mac client setup
node bin/ao-tm.js setup

# Windows destination setup (run in WSL or Git Bash)
npm run windows:check-drives
```

No package install step required for the scripts — they use only built-in macOS/Windows tools.
For the Node CLI: `node >= 18` required (no npm dependencies).
