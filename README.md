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

Copy the message below and send it to opencode (or any AI terminal). The AI deploys everything:

```
Deploy the oc-tgtylab project: clone https://github.com/GeniusHu-tgty/oc-tgtylab.git to ~/oc-tgtylab (with submodules), run scripts/install.sh to complete the installation, then run scripts/healthcheck.sh to verify all components are ready. When finished, tell me how to start using it.
```

### Verify deployment

1. Restart opencode and launch it inside the `oc-tgtylab` directory
2. Press `Tab` (or type `/agents`) to switch to **security-operator** mode
3. Ghost operator identity shown = deployed. Give it a task.

> ⚠️ Use the project from inside the `oc-tgtylab` directory. MCP tools and knowledge base paths are relative to the project root. Move the directory → re-run Option A or B.

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
