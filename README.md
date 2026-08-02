<div align="center">

# 🐙 oc-tgtylab

> Full-spectrum security research workbench

284 MCP tools · 207 knowledge base articles · Max reasoning by default

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-red.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL%20%7C%20macOS%20%7C%20Windows-blue.svg)]()
[![MCP Tools](https://img.shields.io/badge/MCP_Tools-284-green.svg)]()
[![Knowledge Base](https://img.shields.io/badge/KB-207%20Articles-brightgreen.svg)]()

</div>

---

> [中文版](README.zh.md)

## Features

- 🔧 284 MCP automation tools (Pentest / PE reverse / Android / JS reverse / Crypto / Debug)
- 📚 207 technical articles (Web / APK / PE / Crypto / Game Security / Firmware)
- 🧠 Full-spectrum operator mode — direct execution, zero friction, zero disclaimers
- ⚡ Max reasoning strength by default — no manual variant switching
- 🔄 Hunter framework integrated as one MCP server (`hunter_tools`)
- 🖥 Multi-platform (Windows / macOS / Linux / WSL)
- ✅ One-click deploy

## Quick Start

### Option A — one-line install

**Linux / macOS / WSL**, copy and run this line:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.sh)
```

**Windows** (PowerShell), copy and run this line:

```powershell
iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.ps1'))
```

### Option B — deploy via AI prompt

Copy the message below and send it to opencode (or any AI terminal). The AI deploys **both oc-tgtylab and the Hunter subproject**:

```
Deploy the oc-tgtylab project (including the Hunter subproject):
1. Clone https://github.com/GeniusHu-tgty/oc-tgtylab.git to ~/oc-tgtylab with --recurse-submodules so the Hunter subproject (mcp/hunter) is fetched together;
2. Confirm mcp/hunter/mcp_server.py exists and Hunter is ready;
3. Run scripts/install.sh to complete the installation, then run scripts/healthcheck.sh to verify all components are ready;
4. When finished, tell me how to start using it.
```

### Verify deployment

1. Restart opencode and launch it inside the `oc-tgtylab` directory
2. Press `Tab` (or type `/agents` + Enter) to switch to **security-operator** mode
3. Ghost operator identity shown = deployed. Give it a task.

> ⚠️ The installer also writes the **global opencode config** (`~/.config/opencode/opencode.json`),
> so you can press `Tab` to switch to security-operator from **any directory** — no need to `cd` into the project.
> Inside the project directory you get the full MCP toolset; outside it, the MCP servers are still registered (absolute paths).
> Moved the project folder? Re-run Option A or B to fix all paths automatically.

### Tab switching notes (important)

- With an **empty input box**, press `Tab` → cycles `build` / `plan` / `security-operator` (keep pressing until the top shows `security-operator`)
- With **text in the input box**, `Tab` triggers autocomplete, NOT agent switching (that's opencode's keybinding design, not a bug)
- Clear the input first, or type `/agents` + Enter and pick from the list
- Recommended shortcut: `Ctrl+X` then `A` (`<leader>a`) opens the agent list

### Permissions (zero confirmation)

After switching to **security-operator**, all tool operations run automatically — no manual Enter confirmation:
bash / read / edit / write / task (incl. subagent spawn) / webfetch / MCP tools are all `allow`.
If a permission prompt still appears, verify you are actually on `security-operator` (check the agent name above the input).

### Version requirement

Requires **opencode >= 1.15** (`variant` field support; latest 1.18+ recommended).
Older versions may fail to load `variant` / `mode` config, making the custom mode unavailable.
Upgrade: `opencode upgrade` or `npm i -g opencode-ai`.

### Upgrade to latest (no-reinstall for existing users)

**No need to delete the old project** — re-run the same one-line installer, it upgrades in place:

```bash
# Linux / macOS / WSL (existing install)
bash <(curl -fsSL https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.sh)

# Windows PowerShell (existing install)
iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.ps1'))
```

The updater automatically:
1. `git pull` latest code (resets the managed `opencode.json`/`tui.json` first, so local path edits never cause merge conflicts)
2. Updates the Hunter submodule
3. Re-runs install: fixes MCP absolute paths + **writes the global config (Tab works from any directory)**

**Your data is kept**: `cases/` `notes/` `exports/` `patches/` `samples/` `reports/` are all preserved.

## Routing

```
Signal → kb_router → kb_read_file → Technique → MCP tool mapping → Execution
```

| Signal | Board | KB | MCP Family |
|---|---|---|---|
| Web/API/CVE/Cloud | `ctf-website` | 26/118 | `hunter_auto_*` `hunter_stealth_request` `run_ctf_tool` |
| APK/DEX/SO/Frida | `apk-reverse` | 8/20 | `re_android_*` `re_android_frida_*` |
| PE/malware/driver | `pe-reverse` | 9/22 | `re_triage_pe` `re_ghidra_*` `re_sample_full_workup` |
| Crypto/Game/IoT/Radio | `general` | 5/17 | `re_die_scan` `re_rizin_*` `re_solve_crypto_*` |

## Knowledge Base

```
kb/
├── ctf-website/techniques/   26 categories, 118 articles — Full web attack surface
├── apk-reverse/techniques/    8 categories,  20 articles — APK/DEX reverse engineering
├── pe-reverse/techniques/     9 categories,  22 articles — PE binary analysis
├── general/techniques/        5 categories,  17 articles — Crypto / Protocols / Kernel / Game security
└── windows/techniques/        1 category,     2 articles — Windows security
```

## Directory Convention

```
samples/      → Original samples + _quarantine/
exports/      → Tool outputs (yara/sigma/iocs/ghidra)
patches/      → Patch artifacts
notes/        → Analysis notes
reports/      → Final reports
kb/           → Knowledge base
tools/        → Toolchain
cases/        → Case index
```

## System Requirements

| Dependency | Version | Notes |
|------------|---------|-------|
| **OS** | Windows 10/11 / macOS 12+ / Linux / WSL | |
| **Python** | 3.12+ | 3.10/3.11 partial re_* tools unavailable |
| **Node.js** | Any | jsreverser / jshook (optional) |
| **Git** | Any | Clone + submodule |

| AI Tool | Status |
|---------|--------|
| opencode | ✅ Full support |
| Any MCP-capable AI terminal | ✅ (config via opencode.json) |

## Related Projects

- [Hunter](https://github.com/GeniusHu-tgty/Hunter) — independent penetration-testing framework, integrated as `hunter_tools` MCP server (179 tools). See `docs/hunter-integration.md`.

## License

GPL-3.0-only. See [LICENSE](LICENSE).

## Disclaimer

This project is for educational and authorized security research purposes only. Users must ensure they operate within legally authorized scope. Users are solely responsible for any consequences arising from the use of this project.

See [DISCLAIMER.md](DISCLAIMER.md) for the full disclaimer.
