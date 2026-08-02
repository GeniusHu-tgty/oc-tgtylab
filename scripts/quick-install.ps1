# ============================================================
# oc-tgtylab one-line installer (Windows PowerShell)
#   iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/GeniusHu-tgty/oc-tgtylab/main/scripts/quick-install.ps1'))
# ============================================================
$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/GeniusHu-tgty/oc-tgtylab.git"
$InstallDir = Join-Path $HOME "oc-tgtylab"

Write-Host "==> oc-tgtylab quick install" -ForegroundColor Cyan
Write-Host "    target: $InstallDir"

# 前置检查
foreach ($cmd in @("git", "python")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "[FAIL] 缺少 $cmd，请先安装后重试" -ForegroundColor Red
        exit 1
    }
}

# 克隆或更新（无损升级：保留 cases/notes/exports/patches/samples 等数据）
# 升级策略：fetch + reset --hard 对齐远端。
# 老用户本地 opencode.json 等托管文件被安装脚本改过路径，git pull --rebase 会因
# unstaged changes 失败；数据目录仅跟踪 .gitkeep，reset --hard 不影响用户数据。
if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "==> 检测到已存在，执行无损升级（保留本地数据）..." -ForegroundColor Cyan
    Set-Location $InstallDir
    git fetch origin
    git reset --hard origin/main 2>$null
    if ($LASTEXITCODE -ne 0) { git reset --hard origin/master }
    git submodule update --init --recursive
} else {
    Write-Host "==> 克隆仓库 (含 Hunter submodule) ..." -ForegroundColor Cyan
    git clone --recurse-submodules $RepoUrl $InstallDir
    Set-Location $InstallDir
}

# 部署
Write-Host "`n==> 运行部署脚本 ..." -ForegroundColor Cyan
& (Join-Path $InstallDir "scripts\install.ps1")

# 健康检查
Write-Host "`n==> 健康检查 ..." -ForegroundColor Cyan
$Health = Join-Path $InstallDir "scripts\healthcheck.sh"
if (Test-Path $Health) { bash $Health } else { Write-Host "[OK] install.ps1 已输出结果" -ForegroundColor Green }

Write-Host "`n[OK] 部署完成。开始使用:" -ForegroundColor Green
Write-Host "    cd $InstallDir && opencode"
Write-Host "    按 Tab（或 /agents）切换到 security-operator 模式"
