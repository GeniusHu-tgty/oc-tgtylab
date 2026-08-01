#!/usr/bin/env bash
# ============================================================
# oc-tgtylab one-line installer
#   bash <(curl -fsSL https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.sh)
# ============================================================
set -euo pipefail

REPO_URL="https://github.com/GeniusHu-tgty/oc-tgtylab.git"
INSTALL_DIR="${1:-$HOME/oc-tgtylab}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo "==> oc-tgtylab quick install"
echo "    target: $INSTALL_DIR"

for cmd in git curl python3.12 python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    case "$cmd" in
      git)  fail "缺少 git，请先安装: sudo apt install git" ;;
      curl) fail "缺少 curl，请先安装: sudo apt install curl" ;;
      *)    : ;;
    esac
  fi
done
if ! command -v python3.12 >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  fail "缺少 python3 (推荐 3.12+)。"
  exit 1
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "==> 检测到已存在，执行更新..."
  cd "$INSTALL_DIR"
  git pull --rebase || warn "git pull 失败，继续使用现有代码"
  git submodule update --init --recursive
else
  mkdir -p "$(dirname "$INSTALL_DIR")"
  echo "==> 克隆仓库 (含 Hunter submodule) ..."
  git clone --recurse-submodules "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

echo
echo "==> 运行部署脚本 ..."
if [ -x "$INSTALL_DIR/scripts/install.sh" ]; then
  "$INSTALL_DIR/scripts/install.sh"
else
  bash "$INSTALL_DIR/scripts/install.sh"
fi

echo
echo "==> 健康检查 ..."
bash "$INSTALL_DIR/scripts/healthcheck.sh"

echo
ok "部署完成。开始使用:"
echo "    cd $INSTALL_DIR && opencode"
echo "    按 Tab（或 /agents）切换到 security-operator 模式"
