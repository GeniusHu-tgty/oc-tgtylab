@echo off
REM ============================================================
REM oc-tgtylab 启动（Windows）
REM 双击本文件即可：在仓库内 → 直接部署；不在仓库内 → 一键安装
REM ============================================================
setlocal

if exist "%~dp0opencode.json" if exist "%~dp0scripts\install.ps1" (
    echo 检测到 oc-tgtylab 仓库，开始部署...
    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1"
) else (
    echo 未检测到完整仓库，执行一键安装...
    powershell -ExecutionPolicy Bypass -Command "iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.ps1'))"
)

echo.
pause
