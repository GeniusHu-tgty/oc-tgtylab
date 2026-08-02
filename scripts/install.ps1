# ============================================================
# oc-tgtylab — opencode 版 open-tgtylab 一键安装 (Windows PowerShell)
# 用法: 在项目根目录执行  .\scripts\install.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $Root
Write-Host "==> oc-tgtylab installer @ $Root" -ForegroundColor Cyan

# 1. opencode
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Host "[OK] opencode $(& opencode --version)" -ForegroundColor Green
} else {
    Write-Host "==> 未检测到 opencode，尝试 npm 安装..."
    npm install -g opencode-ai
}

# 2. Hunter submodule
if (Test-Path ".gitmodules") {
    Write-Host "==> 初始化 Hunter submodule (mcp/hunter) ..."
    git submodule update --init --recursive
} else {
    Write-Host "[WARN] 未找到 .gitmodules，跳过 submodule" -ForegroundColor Yellow
}

# 3. venv
if (-not (Test-Path ".venv")) {
    python -m venv .venv
}
& ".venv\Scripts\python.exe" -m pip install --upgrade pip -q
& ".venv\Scripts\python.exe" -m pip install -q "mcp>=1.20,<1.29" "dnspython>=2.4" "curl_cffi>=0.6.0"
Write-Host "[OK] venv ready" -ForegroundColor Green

# 4. jsreverser / jshook (optional)
npm install -g jsreverser-mcp @jshookmcp/jshook 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] jsreverser + jshook" -ForegroundColor Green }
else { Write-Host "[WARN] npm 全局安装失败（可选，跳过）" -ForegroundColor Yellow }

# 5. opencode.json 占位符替换（含旧硬编码路径兜底，保证老用户升级后 MCP 指向正确）
$Config = Get-Content "opencode.json" -Raw
$Corrected = ($Root -replace '\\', '/')
if ($Config -match "__TGTYLAB_ROOT__") {
    $Config = $Config.Replace("__TGTYLAB_ROOT__", $Corrected)
    Set-Content "opencode.json" $Config -NoNewline
    Write-Host "[OK] opencode.json 已写入绝对路径: $Root" -ForegroundColor Green
} elseif ($Config -match "/root/oc-tgtylab") {
    $Config = $Config.Replace("/root/oc-tgtylab", $Corrected)
    Set-Content "opencode.json" $Config -NoNewline
    Write-Host "[OK] opencode.json 硬编码路径已修正为: $Root" -ForegroundColor Green
} else {
    Write-Host "[OK] opencode.json 无需替换，跳过" -ForegroundColor Green
}

# 5b. 全局安装（任意目录 Tab 可用）
Write-Host "`n==> 写入 opencode 全局配置（任意目录可用 security-operator 模式）..." -ForegroundColor Cyan
python "$Root\scripts\global-install.py" "$Root"
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] 全局安装完成：任意目录按 Tab 均可切换到 security-operator" -ForegroundColor Green }
else { Write-Host "[WARN] 全局安装失败（不影响项目内使用）" -ForegroundColor Yellow }

# 6. healthcheck
Write-Host "`n==> Healthcheck ===================================" -ForegroundColor Cyan
if (-not (Test-Path "prompts\security-operator.md")) { Write-Host "[FAIL] prompts\security-operator.md 缺失" -ForegroundColor Red }
if (Test-Path ".venv\Scripts\python.exe") { Write-Host "[OK] .venv" -ForegroundColor Green } else { Write-Host "[FAIL] .venv 缺失" -ForegroundColor Red }
if (Test-Path "mcp\hunter\mcp_server.py") { Write-Host "[OK] hunter_tools" -ForegroundColor Green } else { Write-Host "[WARN] mcp\hunter 未就绪（submodule）" -ForegroundColor Yellow }
if (Test-Path "mcp\reverse-lab-tools\reverse_lab_tools_mcp.py") { Write-Host "[OK] reverse-lab-tools" -ForegroundColor Green } else { Write-Host "[FAIL] reverse-lab-tools 缺失" -ForegroundColor Red }

Write-Host "`n==> 完成。开始使用: cd $Root && opencode" -ForegroundColor Green
