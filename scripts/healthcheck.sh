#!/usr/bin/env bash
# ============================================================
# oc-tgtylab — healthcheck：检查安装完整性
# 用法: ./scripts/healthcheck.sh
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "==> oc-tgtylab healthcheck @ $ROOT"
echo

# Core
[ -f opencode.json ] && ok "opencode.json" || fail "opencode.json"
[ -f prompts/security-operator.md ] && ok "prompts/security-operator.md ($(wc -l < prompts/security-operator.md) lines)" || fail "prompts/security-operator.md"

# venv / python
if [ -x .venv/bin/python ]; then
  ok ".venv ($(.venv/bin/python --version 2>&1))"
  .venv/bin/python -c "import mcp" 2>/dev/null && ok "mcp package" || warn "mcp package 未安装"
else
  fail ".venv 缺失（运行 ./scripts/install.sh）"
fi

# Hunter
if [ -f mcp/hunter/mcp_server.py ]; then
  ok "hunter_tools: mcp_server.py"
  [ -d mcp/hunter/core ] && ok "hunter core/" || warn "hunter core/ 缺失"
else
  warn "hunter submodule 未就绪（运行 git submodule update --init --recursive）"
fi

# Reverse-lab-tools
if [ -f mcp/reverse-lab-tools/reverse_lab_tools_mcp.py ]; then
  ok "reverse-lab-tools: reverse_lab_tools_mcp.py"
else
  fail "reverse-lab-tools 缺失"
fi

# Ghidra bridge
if [ -f mcp/ghidra/bridge_mcp_ghidra.py ]; then
  ok "ghidra bridge (默认 disabled，需 Ghidra Server :18080)"
else
  warn "ghidra bridge 缺失"
fi

# Workspace
for d in workspace/cases workspace/kb workspace/samples workspace/exports workspace/notes workspace/patches; do
  [ -d "$d" ] || warn "workspace 子目录缺失: $d"
done
[ -d workspace/kb ] && ok "kb ($(find workspace/kb -name '*.md' | wc -l) 篇)"

# Optional binaries
command -v opencode >/dev/null 2>&1 && ok "opencode $(opencode --version 2>/dev/null)" || warn "opencode 不在 PATH"
command -v jsreverser-mcp >/dev/null 2>&1 && ok "jsreverser-mcp" || warn "jsreverser-mcp 未安装（可选）"
command -v jshook >/dev/null 2>&1 && ok "jshook" || warn "jshook 未安装（可选）"
command -v uv >/dev/null 2>&1 && ok "uv" || warn "uv 未安装（ghidra MCP 需要，可选）"
command -v adb >/dev/null 2>&1 && ok "adb" || warn "adb 未安装（Android 分析可选）"

echo
echo "==> 完成。可选项: Burp MCP (:9876) / Ghidra Server (:18080) / Android 设备"
