<div align="center">

# 🐙 oc-tgtylab

> 全谱系安全研究工作台

284 个 MCP 工具 · 207 篇知识库 · 默认最大思考强度

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-red.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL%20%7C%20macOS%20%7C%20Windows-blue.svg)]()
[![MCP Tools](https://img.shields.io/badge/MCP_Tools-284-green.svg)]()
[![Knowledge Base](https://img.shields.io/badge/KB-207%20Articles-brightgreen.svg)]()

</div>

---

> [English version](README.md)

## 特性

- 🔧 284 个 MCP 自动化工具（渗透 / PE 逆向 / Android / JS 逆向 / 加密 / 调试）
- 📚 207 篇技术知识库（Web / APK / PE / 密码学 / 游戏安全 / 固件）
- 🧠 全谱系操作模式 — 直接执行、零摩擦、零免责声明
- ⚡ 默认最大思考强度 — 无需手动切换
- 🔄 Hunter 框架以单一 MCP 服务集成（`hunter_tools`）
- 🖥 全平台支持（Windows / macOS / Linux / WSL）
- ✅ 一键部署

## 快速开始

### 选项 A — 一行命令安装

**Linux / macOS / WSL**，复制这一行执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.sh)
```

**Windows**（PowerShell），复制这一行执行：

```powershell
iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.ps1'))
```

### 选项 B — 提示词部署（发给 AI）

复制下面这段话，发给 opencode（或任意 AI 终端），AI 会自动完成部署：

```
部署 oc-tgtylab 项目：克隆 https://github.com/GeniusHu-tgty/oc-tgtylab.git 到 ~/oc-tgtylab（含 submodule），运行 scripts/install.sh 完成安装，再运行 scripts/healthcheck.sh 验证所有组件就绪。完成后告诉我如何开始使用。
```

### 确认部署

1. 重启 opencode，在 `oc-tgtylab` 目录内启动
2. 按 `Tab` 键（或输入 `/agents`）切换到 **security-operator** 模式
3. 看到 Ghost 操作员身份即部署成功，直接下达任务

> ⚠️ 必须在 `oc-tgtylab` 目录内使用。MCP 工具和知识库路径均相对于项目根目录。移动目录后重跑选项 A 或 B。

## 路由

```
信号 → kb_router → kb_read_file → 技术文档 → MCP 工具映射 → 执行
```

| 信号 | Board | KB 分类/文件 | MCP 工具族 |
|------|-------|-------------|-----------|
| Web/API/CVE/Cloud | `ctf-website` | 26/118 | `hunter_auto_*` `hunter_stealth_request` `run_ctf_tool` |
| APK/DEX/SO/Frida | `apk-reverse` | 8/20 | `re_android_*` `re_android_frida_*` |
| PE/恶意样本/驱动 | `pe-reverse` | 9/22 | `re_triage_pe` `re_ghidra_*` `re_sample_full_workup` |
| 密码/游戏/IoT/无线电 | `general` | 5/17 | `re_die_scan` `re_rizin_*` `re_solve_crypto_*` |

## 知识库

```
kb/
├── ctf-website/techniques/   26 类 118 篇 — Web 安全全覆盖
├── apk-reverse/techniques/    8 类  20 篇 — APK/DEX 逆向
├── pe-reverse/techniques/     9 类  22 篇 — PE 二进制分析
├── general/techniques/        5 类  17 篇 — 密码学/协议/内核/游戏安全
└── windows/techniques/        1 类   2 篇 — Windows 安全
```

## 目录约定

```
samples/      → 原始样本 + _quarantine/
exports/      → 工具输出（yara/sigma/iocs/ghidra）
patches/      → Patch 产物
notes/        → 分析笔记
reports/      → 最终报告
kb/           → 知识库
tools/        → 工具链
cases/        → 案例索引
```

## 系统要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| **OS** | Windows 10/11 / macOS 12+ / Linux / WSL | |
| **Python** | 3.12+ | 3.10/3.11 部分 re_* 工具不可用 |
| **Node.js** | 任意 | jsreverser / jshook（可选） |
| **Git** | 任意 | 克隆 + submodule |

| AI 工具 | 状态 |
|---------|------|
| opencode | ✅ 完整支持 |
| 任意支持 MCP 的 AI 终端 | ✅（通过 opencode.json 配置） |

## 相关项目

- [Hunter](https://github.com/GeniusHu-tgty/Hunter) — 独立渗透测试框架，以 `hunter_tools` MCP 服务集成（179 个工具）。

## 许可

GPL-3.0-only. 详见 [LICENSE](LICENSE)。

## 免责声明

本项目仅用于教育和授权安全研究。用户必须确保其操作在法律授权范围内，并对因使用本项目产生的一切后果自行负责。

完整版见 [DISCLAIMER.md](DISCLAIMER.md)。
