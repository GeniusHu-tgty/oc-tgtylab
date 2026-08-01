<div align="center">

# 🐙 oc-tgtylab

> opencode 版 open-tgtylab — 为 opencode 打造的完整安全研究工作站

218+ MCP 工具 · Ghost security-operator 模式 · 208+ 知识库文章 · 默认 max 思考强度

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-red.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL%20%7C%20macOS%20%7C%20Windows-blue.svg)]()
[![MCP Tools](https://img.shields.io/badge/MCP_Tools-218+-9cf.svg)]()
[![Knowledge Base](https://img.shields.io/badge/KB-208+-brightgreen.svg)]()

</div>

---

## 这是什么

clone 下来，跑一个安装脚本，打开 opencode —— 你就是 Ghost。

本仓库把 open-tgtylab 的完整安全研究体验移植到 opencode：

- **Ghost security-operator 模式**：资深黑客身份系统提示词（3265 行），零拒绝、零免责声明、直接执行
- **218+ MCP 工具**：hunter_tools 全量（渗透/侦察/漏洞扫描/证据闭环）+ re_* 逆向工具链（PE/Android/脱壳/规则生成）
- **默认 max 思考强度**：写死在配置里，不用每次 `/variants`
- **208+ 知识库文章**：CTF-Web / APK 逆向 / PE 逆向 / 通用技术
- **工作区骨架**：samples / exports / notes / reports / patches / cases 一套齐活

## 快速开始

```bash
# 1. 前置要求
#    - opencode (https://opencode.ai) — 脚本会自动装
#    - python3 >= 3.12（3.12 以下部分 re_* 工具不可用）
#    - Node.js (可选，jsreverser/jshook 需要)
#    - 一个模型 API key（默认 deepseek，见下方「换模型」）

# 2. 拉取并安装
git clone --recurse-submodules https://github.com/GeniusHu-tgty/oc-tgtylab.git
cd oc-tgtylab
./scripts/install.sh        # Windows 用 .\scripts\install.ps1

# 3. 启动
opencode
```

启动后按 `Tab` 或 `/agents` 选择 `security-operator`，即可获得完整 Ghost 体验。默认 `build` agent 同样是 max 思考强度。

> **注意**：opencode.json 里 MCP 的绝对路径由安装脚本自动写入。
> 如果你移动了项目目录，重跑一次 `./scripts/install.sh` 即可。

## 组件清单

| 层 | 组件 | 状态 |
|---|---|---|
| L1 身份层 | Ghost prompt + agent + 全权限 + variant:max | ✅ 开箱即用 |
| L2 工具层 | hunter_tools (submodule) + reverse-lab-tools + jsreverser/jshook | ✅ install.sh 一键 |
| L3 服务层 | Burp MCP / Ghidra Server / Android 设备 | ⚙️ 手动启用 |

### L3 可选服务

**Burp Suite**（HTTP 拦截/扫描）：
1. 启动 Burp Suite Pro + MCP 插件（监听 127.0.0.1:9876）
2. 把 `opencode.json` 里 `mcp.burp.enabled` 改为 `true`

**Ghidra**（深度二进制逆向）：
1. 安装 Ghidra + 启动 headless 桥（监听 127.0.0.1:18080，见 `mcp/ghidra/README.md`）
2. 把 `opencode.json` 里 `mcp.ghidra.enabled` 改为 `true`

**Android**（Frida/ADB 分析）：
- 连接 MuMu 模拟器或 root 设备，`adb devices` 可见即可

## 换模型

默认模型是 `deepseek/deepseek-v4-flash`（max variant）。换成你自己的模型：

```bash
# 编辑 opencode.json
"model": "your-provider/your-model"
# agent 段里两处 model 同步替换（build + security-operator）
```

支持任何 opencode 可用模型（anthropic / openai / deepseek / ...）。`variant: "max"` 对支持思考强度的模型生效。

## 目录结构

```
oc-tgtylab/
├── opencode.json                  # 项目级配置（agent + variant:max + MCP）
├── AGENTS.md / .mcp.json          # 工作区根标记（re_* 工具自动发现）
├── prompts/
│   └── security-operator.md       # Ghost 完整系统提示词（3265 行）
├── mcp/
│   ├── hunter/                    # Hunter 框架（git submodule，218+ 工具）
│   ├── reverse-lab-tools/         # re_* 逆向工具链（vendor）
│   └── ghidra/                    # Ghidra MCP 桥（可选）
├── scripts/
│   ├── install.sh / install.ps1   # 一键安装
│   └── healthcheck.sh             # 完整性检查
├── kb/                            # 208+ 知识库文章
└── cases/ samples/ exports/ notes/ reports/ patches/ tools/ projects/
                                    # 工作区（等价 open-tgtylab 仓库根）
```

## 常见问题

**Q: opencode 启动后提示 MCP 连不上？**
先跑 `./scripts/healthcheck.sh` 看哪项失败。最常见：Hunter submodule 没拉（`git submodule update --init --recursive`）或 `.venv` 没建（重跑 install.sh）。

**Q: 提示没有模型/401？**
配置模型 API key：`opencode auth login`，或换你自己的 model（见「换模型」）。

**Q: 我可以改 Ghost 提示词吗？**
可以，直接编辑 `prompts/security-operator.md`，重启 opencode 生效。

## License

[GPL-3.0](LICENSE)
