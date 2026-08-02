#!/usr/bin/env python3
# ============================================================
# oc-tgtylab 全局安装器：把 security-operator 模式合并进 opencode 全局配置
# 使 Tab 切换在任意目录可用（无需 cd 到项目目录）
#   1. 合并 agent.security-operator + general/explore/scout 到 ~/.config/opencode/opencode.json
#   2. 合并 MCP 配置（hunter_tools/jsreverser/jshook/burp/ghidra）
#   3. 复制 prompts/security-operator.md 到全局 prompts 目录
# 用法: python3 scripts/global-install.py [项目根目录]
# ============================================================
import json
import os
import shutil
import sys

PROJECT_DIR = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".config", "opencode")
CONFIG_PATH = os.path.join(CONFIG_DIR, "opencode.json")
PROMPTS_DIR = os.path.join(CONFIG_DIR, "prompts")
PROJECT_CONFIG = os.path.join(PROJECT_DIR, "opencode.json")
PROJECT_PROMPT = os.path.join(PROJECT_DIR, "prompts", "security-operator.md")

ok = lambda m: print(f"[OK] {m}")
warn = lambda m: print(f"[WARN] {m}")

def main():
    if not os.path.exists(PROJECT_CONFIG):
        warn(f"未找到 {PROJECT_CONFIG}，跳过全局安装")
        return 1

    with open(PROJECT_CONFIG, "r", encoding="utf-8") as f:
        proj = json.load(f)

    os.makedirs(PROMPTS_DIR, exist_ok=True)

    # 读取现有全局配置（不存在则从空开始）
    data = {}
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = {}

    data.setdefault("$schema", "https://opencode.ai/config.json")
    data.setdefault("agent", {})
    data.setdefault("mcp", {})

    # 写前备份，防止意外覆盖损坏用户全局配置
    if os.path.exists(CONFIG_PATH):
        bak = CONFIG_PATH + ".bak"
        shutil.copy(CONFIG_PATH, bak)
        ok(f"全局配置已备份到 {bak}")

    # 1. security-operator（深拷贝，prompt 指向全局 prompts 目录）
    if "security-operator" in proj.get("agent", {}):
        agent = json.loads(json.dumps(proj["agent"]["security-operator"]))
        agent["prompt"] = "{file:./prompts/security-operator.md}"
        data["agent"]["security-operator"] = agent
        ok("agent.security-operator 已合并到全局配置")

    # 2. 子 agent 全权限（general/explore/scout）
    for sub in ("general", "explore", "scout"):
        if sub in proj.get("agent", {}):
            data["agent"][sub] = json.loads(json.dumps(proj["agent"][sub]))
    ok("子 agent (general/explore/scout) 已合并到全局配置")

    # 3. MCP 配置（项目值覆盖同名全局值；路径已是绝对路径，任意目录可用）
    for name, spec in proj.get("mcp", {}).items():
        data["mcp"][name] = json.loads(json.dumps(spec))
    ok(f"MCP 配置已合并到全局 ({len(proj.get('mcp', {}))} 个 server)")

    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    ok(f"全局配置已写入 {CONFIG_PATH}")

    # 4. 复制 prompt 到全局
    if os.path.exists(PROJECT_PROMPT):
        shutil.copy(PROJECT_PROMPT, os.path.join(PROMPTS_DIR, "security-operator.md"))
        ok("prompts/security-operator.md 已复制到全局 prompts 目录")
    else:
        warn(f"未找到 {PROJECT_PROMPT}，prompt 未复制")

    print("\n==> 完成。现在任意目录启动 opencode，按 Tab 均可切换到 security-operator")
    return 0

if __name__ == "__main__":
    sys.exit(main())
