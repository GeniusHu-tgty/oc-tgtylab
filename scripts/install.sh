#!/usr/bin/env bash
# ============================================================
# oc-tgtylab — opencode 版 open-tgtylab 一键安装
# 用法: ./scripts/install.sh
# 功能: 检查 opencode → 拉 Hunter submodule → 建 venv → 装依赖
#       → 替换 opencode.json 占位符 → healthcheck
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "==> oc-tgtylab installer @ $ROOT"

# ---------- 1. python (prefer 3.12+, reverselab_mcp 需要 3.12+ 语法) ----------
PYTHON=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    PYTHON="$cand"
    break
  fi
done
if [ -z "$PYTHON" ]; then
  fail "未找到 python3 (需要 3.10+，推荐 3.12+)。"
  exit 1
fi
PY_VER=$($PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
ok "python: $PYTHON $PY_VER"
case "$PY_VER" in
  3.10|3.11)
    warn "Python $PY_VER 可能无法加载部分 re_* 工具（reverselab_mcp 需要 3.12+），建议安装 3.12+"
    ;;
esac

# ---------- 2. opencode ----------
if command -v opencode >/dev/null 2>&1; then
  ok "opencode: $(opencode --version 2>/dev/null || echo present)"
else
  echo "==> 未检测到 opencode，尝试安装..."
  if command -v npm >/dev/null 2>&1; then
    npm install -g opencode-ai
    ok "opencode installed via npm"
  else
    echo "    没有 npm。请手动安装 opencode: https://opencode.ai/docs/"
    echo "    或安装 Node.js 后重跑本脚本。"
  fi
fi

# ---------- 3. Hunter submodule ----------
if [ -f .gitmodules ]; then
  echo "==> 初始化 Hunter submodule (mcp/hunter) ..."
  git submodule update --init --recursive || warn "submodule 拉取失败，稍后执行: git submodule update --init --recursive"
  if [ -f mcp/hunter/mcp_server.py ]; then
    ok "Hunter: mcp_server.py"
  else
    warn "Hunter 未就绪"
  fi
else
  warn "未找到 .gitmodules（可能是源码包分发），跳过 submodule"
fi

# ---------- 4. Python venv + deps ----------
echo "==> 创建 Python venv (.venv, $PYTHON) ..."
if [ ! -d .venv ]; then
  $PYTHON -m venv .venv
fi
.venv/bin/python -m pip install --upgrade pip -q
echo "==> 安装 MCP 依赖 (mcp / dnspython / curl_cffi / pyyaml) ..."
.venv/bin/pip install -q --timeout 60 "mcp>=1.20,<1.29" "dnspython>=2.4" "curl_cffi>=0.6.0" "pyyaml" || { warn "官方源超时，改用清华镜像重试..."; .venv/bin/pip install -q --timeout 60 -i https://pypi.tuna.tsinghua.edu.cn/simple "mcp>=1.20,<1.29" "dnspython>=2.4" "curl_cffi>=0.6.0" "pyyaml"; }
# hunter 仓库自身 pyproject 里的依赖（如果包含本地包）
if [ -f mcp/hunter/pyproject.toml ]; then
  .venv/bin/pip install -q -e mcp/hunter 2>/dev/null || \
    warn "hunter 本地包安装失败（不影响，依赖已装）"
fi
ok "venv ready"

# ---------- 5. jsreverser / jshook (optional) ----------
echo "==> 安装 JS 逆向工具 (jsreverser-mcp / jshook, 可选) ..."
if command -v npm >/dev/null 2>&1; then
  timeout 120 npm install -g jsreverser-mcp @jshookmcp/jshook 2>/dev/null && ok "jsreverser + jshook" || warn "npm 全局安装失败/超时（跳过，可手动: npm i -g jsreverser-mcp @jshookmcp/jshook）"
else
  warn "npm 不存在，跳过 jsreverser/jshook"
fi

# ---------- 6. opencode.json 占位符替换 ----------
echo "==> 写入 opencode.json 绝对路径 ..."
if grep -q "__TGTYLAB_ROOT__" opencode.json; then
  sed -i "s|__TGTYLAB_ROOT__|$ROOT|g" opencode.json
  ok "opencode.json 已指向 $ROOT"
else
  ok "opencode.json 无占位符，跳过"
fi

# ---------- 7. healthcheck ----------
echo
echo "==> Healthcheck ==================================="
HEALTH_PASS=1
[ -f "$ROOT/prompts/security-operator.md" ] || { fail "prompts/security-operator.md 缺失"; HEALTH_PASS=0; }
[ -f "$ROOT/.venv/bin/python" ] || { fail ".venv 缺失"; HEALTH_PASS=0; }
[ -f "$ROOT/mcp/hunter/mcp_server.py" ] || { warn "mcp/hunter 未就绪（检查 submodule）"; }
[ -f "$ROOT/mcp/reverse-lab-tools/reverse_lab_tools_mcp.py" ] || { warn "reverse-lab-tools 缺失"; }
command -v opencode >/dev/null 2>&1 || warn "opencode 不在 PATH"
command -v jsreverser-mcp >/dev/null 2>&1 || warn "jsreverser-mcp 未安装（可选）"
command -v jshook >/dev/null 2>&1 || warn "jshook 未安装（可选）"

if [ "$HEALTH_PASS" -eq 1 ]; then
  echo
  ok "安装完成。开始使用:"
  echo "    cd $ROOT && opencode"
  echo "    启动后切换/确认 agent: security-operator (Tab 或 /agents)"
  echo "    默认思考强度: max (已写死，无需 /variants)"
else
  echo
  fail "存在缺失项，请按上面提示修复后重跑 ./scripts/install.sh"
  exit 1
fi
