#!/usr/bin/env bash
# ============================================================
# oc-tgtylab 启动（Linux / macOS / WSL）
# 在仓库内运行 → 直接部署；不在仓库内 → 自动一键安装
# 用法: ./启动.sh   或   bash 启动.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/opencode.json" ] && [ -f "$SCRIPT_DIR/scripts/install.sh" ]; then
  # 已在仓库内：直接部署
  cd "$SCRIPT_DIR"
  echo "==> 检测到 oc-tgtylab 仓库，开始部署 ..."
  ./scripts/install.sh
  echo "==> 健康检查 ..."
  ./scripts/healthcheck.sh
else
  # 不在仓库内（比如刚下载的源码包）：走一键安装
  echo "==> 未检测到完整仓库，执行一键安装 ..."
  bash <(curl -fsSL https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.sh) "$HOME/oc-tgtylab"
fi
