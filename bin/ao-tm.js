#!/usr/bin/env node
// bin/ao-tm.js
// Avatar Of Time Machine — CLI entry point
// No npm dependencies required (Node built-ins only, node >= 18)
// Usage: ao-tm <command> [options]
//   ao-tm check       — detect system, recommend path
//   ao-tm setup       — interactive full setup wizard
//   ao-tm status      — show TM status
//   ao-tm diagnose    — diagnose backup failures

'use strict';

const { execSync, spawnSync } = require('child_process');
const { platform } = require('os');
const path = require('path');
const fs = require('fs');

const ROOT = path.resolve(__dirname, '..');
const isMac = platform() === 'darwin';
const isWin = platform() === 'win32';

const COMMANDS = {
  check: cmdCheck,
  setup: cmdSetup,
  status: cmdStatus,
  diagnose: cmdDiagnose,
  help: cmdHelp,
};

// ─── helpers ────────────────────────────────────────────────────────────────

function run(cmd, opts = {}) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: opts.stdio ?? 'pipe', ...opts }).trim();
  } catch (e) {
    return opts.fallback ?? '';
  }
}

function runScript(relPath) {
  const abs = path.join(ROOT, relPath);
  if (!fs.existsSync(abs)) {
    console.error(`Script not found: ${abs}`);
    process.exit(1);
  }
  const result = spawnSync('/bin/bash', [abs], { stdio: 'inherit' });
  process.exit(result.status ?? 0);
}

function runPS(relPath) {
  const abs = path.join(ROOT, relPath);
  const result = spawnSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', abs], { stdio: 'inherit' });
  process.exit(result.status ?? 0);
}

function header(title) {
  const line = '═'.repeat(title.length + 4);
  console.log(`\n╔${line}╗`);
  console.log(`║  ${title}  ║`);
  console.log(`╚${line}╝\n`);
}

// ─── commands ────────────────────────────────────────────────────────────────

function cmdCheck() {
  header('AO_TimeMachine — System Check');

  if (isMac) {
    const osVer = run('sw_vers -productVersion');
    const osMajor = parseInt(osVer.split('.')[0], 10);
    const computer = run('scutil --get ComputerName');
    const uuid = run("system_profiler SPHardwareDataType | awk '/Hardware UUID/{print $3}'");
    const model = run("system_profiler SPHardwareDataType | awk -F': ' '/Model Name/{print $2; exit}'");
    const driveGB = parseInt(run("df / | awk 'NR==2{print $2 * 512 / 1024 / 1024 / 1024}'"), 10);
    const recSize = Math.ceil((driveGB * 3) / 100) * 100;

    console.log(`  Platform     : macOS ${osVer}`);
    console.log(`  Computer     : ${computer}`);
    console.log(`  Model        : ${model}`);
    console.log(`  UUID         : ${uuid}`);
    console.log(`  Drive        : ~${driveGB} GB`);
    console.log(`  Bundle name  : ${computer}_${uuid}.sparsebundle`);
    console.log(`  Rec TM cap   : ${recSize}g`);
    console.log('');

    if (osMajor === 12) {
      console.log('  ⚠️  macOS Monterey: native SMB TM is broken.');
      console.log('     Use the sparsebundle hack for ALL network destinations.');
    } else if (osMajor >= 13) {
      console.log('  ✅ macOS 13+: native TM works with Samba+fruit destinations.');
      console.log('     Windows SMB still requires the sparsebundle hack.');
    } else {
      console.log('  ✅ macOS ≤11: AFP or sparsebundle hack for network destinations.');
    }

    console.log('');
    console.log('  Run `ao-tm setup` for the interactive setup wizard.');

  } else if (isWin) {
    console.log('  Platform: Windows');
    console.log('  Run `npm run windows:check-drives` for drive inventory.');
    console.log('  Run `npm run windows:create-share` to create an SMB share.');
  } else {
    console.log(`  Platform: ${platform()} — see knowledge/phase-space.md for Linux/NAS setup.`);
  }
}

function cmdSetup() {
  header('AO_TimeMachine — Setup Wizard');

  if (isMac) {
    const osVer = run('sw_vers -productVersion');
    const osMajor = parseInt(osVer.split('.')[0], 10);

    console.log(`  macOS ${osVer} detected.\n`);
    console.log('  What type of destination are you setting up?');
    console.log('');
    console.log('  [1] Windows PC (plain SMB) → sparsebundle hack (recommended for Windows)');
    console.log('  [2] Linux / NAS with Samba fruit VFS → native TM');
    console.log('  [3] USB drive → native TM');
    console.log('  [4] Run hardware check only');
    console.log('');

    const readline = require('readline');
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question('  Enter choice (1-4): ', (answer) => {
      rl.close();
      switch (answer.trim()) {
        case '1':
          console.log('\n  → Sparsebundle path. Running create-sparsebundle.sh...\n');
          runScript('scripts/mac/create-sparsebundle.sh');
          break;
        case '2':
        case '3':
          console.log('\n  → Native TM path.');
          console.log('  Connect your destination, then run:');
          console.log("    sudo tmutil setdestination -ap smb://USER@HOST/SHARE");
          console.log('  (or select from: System Settings → General → Time Machine → Add Backup Disk)');
          process.exit(0);
          break;
        case '4':
          runScript('scripts/mac/check-hardware.sh');
          break;
        default:
          console.log('  Invalid choice.');
          process.exit(1);
      }
    });

  } else if (isWin) {
    console.log('  Windows detected. For destination setup, run in PowerShell (as Admin):');
    console.log('    npm run windows:check-drives');
    console.log('    npm run windows:create-share');
  } else {
    console.log('  See knowledge/phase-space.md for Linux/NAS setup paths.');
  }
}

function cmdStatus() {
  if (!isMac) {
    console.log('Status command requires macOS.');
    process.exit(1);
  }
  runScript('scripts/mac/status.sh');
}

function cmdDiagnose() {
  if (!isMac) {
    console.log('Diagnose command requires macOS.');
    process.exit(1);
  }

  header('AO_TimeMachine — Diagnostics');

  const checks = [
    ['TM destination configured',
      () => run('tmutil destinationinfo') || null,
      v => v && !v.includes('No destinations')],
    ['Time Machine volume mounted',
      () => fs.existsSync('/Volumes/Time Machine') ? 'yes' : null,
      v => v === 'yes'],
    ['Backup currently running',
      () => { const s = run('tmutil status'); return s.includes('"Running" = 1') ? 'yes' : 'no'; },
      v => true], // informational only
    ['Last backup exists',
      () => run('tmutil latestbackup', { fallback: null }),
      v => v && v.length > 0],
    ['Mount LaunchAgent installed',
      () => { const f = fs.readdirSync(process.env.HOME + '/Library/LaunchAgents').find(x => x.includes('timemachine-mount')); return f ?? null; },
      v => v !== null],
    ['Mount log exists',
      () => fs.existsSync(process.env.HOME + '/Library/Logs/timemachine-mount.log') ? 'yes' : null,
      v => v === 'yes'],
  ];

  let allOk = true;
  for (const [label, getValue, isOk] of checks) {
    let val, ok;
    try { val = getValue(); ok = isOk(val); } catch { val = null; ok = false; }
    const icon = ok ? '✅' : '❌';
    if (!ok) allOk = false;
    console.log(`  ${icon}  ${label}: ${val ?? '(none)'}`);
  }

  console.log('');
  if (!allOk) {
    console.log('  See knowledge/phase-space.md → Common Failure Modes for fixes.');
    console.log('  Run: npm run mac:status  for detailed logs.');
  } else {
    console.log('  All checks passed.');
  }
}

function cmdHelp() {
  console.log(`
Avatar Of Time Machine — @vgm9/ao-timemachine

USAGE
  ao-tm <command>

COMMANDS
  check     Detect system, show macOS version, UUID, drive size, TM compatibility
  setup     Interactive setup wizard (Mac: sparsebundle or native TM; Windows: share)
  status    Show TM destination, backup status, last backup, LaunchAgent state
  diagnose  Run diagnostic checks and report what's broken
  help      Show this message

NPM SCRIPTS (also available)
  npm run mac:check-hardware        Hardware profile
  npm run mac:create-sparsebundle   Create + copy sparsebundle to share
  npm run mac:install-launchagent   Install auto-mount LaunchAgent
  npm run mac:status                Full status report
  npm run windows:check-drives      Drive inventory (Windows)
  npm run windows:create-share      Create SMB share (Windows, Admin required)
  npm run windows:wsl-samba         WSL2 Samba native TM setup (Windows/WSL2)

KNOWLEDGE BASE
  knowledge/phase-space.md          Full decision tree for all sub-cases
  knowledge/destination-types.md    Per-destination capabilities and limits
  knowledge/macos-compatibility.md  Per-macOS-version TM behavior
`);
}

// ─── dispatch ────────────────────────────────────────────────────────────────

const cmd = process.argv[2] ?? 'help';
const fn = COMMANDS[cmd];
if (!fn) {
  console.error(`Unknown command: ${cmd}`);
  cmdHelp();
  process.exit(1);
}
fn();
