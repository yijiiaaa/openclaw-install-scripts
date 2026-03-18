#
# OpenClaw 一键安装脚本 (Windows)
# 用法：powershell -ExecutionPolicy Bypass -File install-openclaw.ps1
#

# ── 强制 UTF-8 编码（解决中文乱码）──
# 注意：不使用 chcp 65001，它会导致旧版控制台 CJK 字符重复显示
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ── 执行策略自修复：如果当前策略阻止脚本运行，自动以 Bypass 重启 ──
if ($MyInvocation.MyCommand.Path) {
    try {
        $policy = Get-ExecutionPolicy -Scope Process
        if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
            Write-Host "  [INFO] 检测到执行策略为 $policy，正在以 Bypass 策略重新启动..." -ForegroundColor Blue
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Wait -NoNewWindow
            exit $LASTEXITCODE
        }
    } catch {}
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ── 颜色输出 ──
function Write-Info { param($Msg) Write-Host "  [INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Ok   { param($Msg) Write-Host "  [OK]   " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn { param($Msg) Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err  { param($Msg) Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Step { param($Msg) Write-Host "`n━━━ $Msg ━━━`n" -ForegroundColor Cyan }

# ── 全局变量 ──
$RequiredNodeMajor = 22
$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }

function Get-LocalAppData {
    if ($env:LOCALAPPDATA) { return $env:LOCALAPPDATA }
    return (Join-Path $HOME "AppData\Local")
}

# ── 工具函数 ──
function Refresh-PathEnv {
    $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Add-ToUserPath {
    param([string]$Dir)
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$Dir;$currentPath", "User")
        $env:PATH = "$Dir;$env:PATH"
        Write-Info "已将 $Dir 添加到用户 PATH"
    }
}

function Get-NodeVersion {
    param([string]$NodeExe = "node")
    try {
        $output = & $NodeExe -v 2>$null
        if ($output -match "v(\d+)") {
            $major = [int]$Matches[1]
            if ($major -ge $RequiredNodeMajor) {
                return $output.Trim()
            }
        }
    } catch {}
    return $null
}

function Get-NpmCmd {
    return "npm"
}

function Get-PnpmCmd {
    $defaultPnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    $cmd = Join-Path $defaultPnpmHome "pnpm.cmd"
    if (Test-Path $cmd) { return $cmd }
    return "pnpm.cmd"
}

function Ensure-PnpmHome {
    $pnpmHome = $env:PNPM_HOME
    if (-not $pnpmHome) {
        $pnpmHome = [Environment]::GetEnvironmentVariable("PNPM_HOME", "User")
    }
    if (-not $pnpmHome) {
        $pnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    }
    $env:PNPM_HOME = $pnpmHome
    if ($env:PATH -notlike "*$pnpmHome*") { $env:PATH = "$pnpmHome;$env:PATH" }
    $savedHome = [Environment]::GetEnvironmentVariable("PNPM_HOME", "User")
    if ($savedHome -ne $pnpmHome) {
        [Environment]::SetEnvironmentVariable("PNPM_HOME", $pnpmHome, "User")
        Write-Info "已持久化 PNPM_HOME=$pnpmHome"
    }
    Add-ToUserPath $pnpmHome
    
    # 额外添加 npm 全局 bin 目录（pnpm 可能安装在这里）
    $npmGlobalBin = Join-Path $HOME "AppData\Roaming\npm"
    Add-ToUserPath $npmGlobalBin
}

function Download-File {
    param([string]$Dest, [string[]]$Urls)
    foreach ($url in $Urls) {
        $hostName = ([Uri]$url).Host
        Write-Info "正在从 $hostName 下载..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $Dest -UseBasicParsing -TimeoutSec 300
            Write-Ok "下载完成"
            return $true
        } catch {
            Write-Warn "从 $hostName 下载失败，尝试备用源..."
        }
    }
    return $false
}

# ── 安装 Node.js ──
function Install-NodeDirect {
    Write-Info "正在直接下载安装 Node.js v22..."
    
    $version = "v22.16.0"  # 使用满足 OpenClaw 要求的版本
    $filename = "node-$version-win-$($Arch).zip"
    $tmpPath = Join-Path $env:TEMP "openclaw-install"
    $tmpFile = Join-Path $tmpPath $filename
    $installDir = Join-Path (Get-LocalAppData) "nodejs"
    
    New-Item -ItemType Directory -Force -Path $tmpPath | Out-Null
    
    $downloaded = Download-File -Dest $tmpFile -Urls @(
        "https://npmmirror.com/mirrors/node/$version/$filename",
        "https://nodejs.org/dist/$version/$filename"
    )
    
    if (-not $downloaded) {
        Write-Err "Node.js 下载失败，请检查网络连接"
        return $false
    }
    
    try {
        Write-Info "正在解压安装..."
        Expand-Archive -Path $tmpFile -DestinationPath $tmpPath -Force
        if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
        Move-Item (Join-Path $tmpPath "node-$version-win-$($Arch)") $installDir
        $env:PATH = "$installDir;$env:PATH"
        Add-ToUserPath $installDir
    } catch {
        Write-Err "安装失败：$_"
        Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
    
    $ver = Get-NodeVersion
    if ($ver) {
        Write-Ok "Node.js $ver 安装成功"
        return $true
    }
    Write-Warn "Node.js 安装完成但验证失败"
    return $false
}

# ── 安装 Git ──
function Get-GitVersion {
    try {
        $output = & git --version 2>$null
        return $output.Trim()
    } catch {}
    return $null
}

function Install-GitDirect {
    Write-Info "正在下载 Git for Windows..."
    $filename = "Git-2.44.0-64-bit.exe"
    $tmpPath = Join-Path $env:TEMP "openclaw-install"
    $tmpFile = Join-Path $tmpPath $filename
    
    New-Item -ItemType Directory -Force -Path $tmpPath | Out-Null
    
    $downloaded = Download-File -Dest $tmpFile -Urls @(
        "https://registry.npmmirror.com/-/binary/git-for-windows/v2.44.0.windows.1/$filename",
        "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/$filename"
    )
    
    if (-not $downloaded) {
        Write-Err "Git 下载失败，请检查网络连接"
        Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    Write-Info "正在静默安装 Git..."
    try {
        Start-Process -FilePath $tmpFile -ArgumentList "/VERYSILENT","/NORESTART","/NOCANCEL","/SP-","/CLOSEAPPLICATIONS","/RESTARTAPPLICATIONS" -Wait
        Refresh-PathEnv
        $ver = Get-GitVersion
        if ($ver) {
            Write-Ok "$ver 安装成功"
            Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
            return $true
        }
    } catch {
        Write-Err "Git 安装失败：$_"
    }
    
    Remove-Item $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
    return $false
}

# ── 主流程步骤 ──
function Step-CheckNode {
    Write-Step "步骤 1/5: 准备 Node.js 环境"
    
    $ver = Get-NodeVersion
    if ($ver) {
        Write-Ok "Node.js $ver 已安装，版本满足要求 (>= 22)"
        return $true
    }
    
    $existingVer = try { & node -v 2>$null } catch { $null }
    if ($existingVer) {
        Write-Warn "检测到 Node.js $existingVer，版本过低，需要 v22 以上"
    } else {
        Write-Warn "未检测到 Node.js"
    }
    
    Write-Info "正在自动安装 Node.js v22..."
    if (Install-NodeDirect) { return $true }
    
    Write-Err "安装失败，请检查网络连接后重试"
    return $false
}

function Step-CheckGit {
    Write-Step "步骤 2/5: 准备 Git 环境"
    
    $ver = Get-GitVersion
    if ($ver) {
        Write-Ok "$ver 已安装"
        return $true
    }
    
    Write-Warn "未检测到 Git，正在自动安装..."
    if (Install-GitDirect) { return $true }
    
    Write-Err "Git 自动安装失败，请手动安装 Git 后重试"
    Write-Host "  下载地址：https://git-scm.com/downloads"
    return $false
}

function Step-InstallPnpm {
    Write-Step "步骤 3/5: 安装 pnpm"
    
    $pnpmCmd = Get-PnpmCmd
    try {
        $pnpmVer = (& $pnpmCmd -v 2>$null).Trim()
        if ($pnpmVer) {
            Write-Ok "pnpm $pnpmVer 已安装，跳过安装步骤"
            Ensure-PnpmHome
            return $true
        }
    } catch {}
    
    $npmCmd = Get-NpmCmd
    Write-Info "正在安装 pnpm..."
    try {
        & $npmCmd install -g pnpm 2>$null | Out-Null
        $pnpmVer = (& $pnpmCmd -v 2>$null).Trim()
        Write-Ok "pnpm $pnpmVer 安装成功"
        Ensure-PnpmHome
        return $true
    } catch {
        Write-Err "pnpm 安装失败：$_"
        return $false
    }
}

function Step-InstallOpenClaw {
    Write-Step "步骤 4/5: 安装 OpenClaw"
    
    Write-Info "正在安装 OpenClaw，请耐心等待..."
    $pnpmCmd = Get-PnpmCmd
    
    try {
        # 重定向错误流，忽略警告，只关注实际错误
        $result = & $pnpmCmd install -g openclaw@latest 2>&1
        
        # 检查是否有真正的错误（只匹配 ERROR 级别，排除 WARN）
        # npm 的错误行通常以 "npm ERR!" 开头，或者包含 "error" 但不包含 "warn"
        $hasRealError = $result | Where-Object { 
            $_ -match 'pnpm ERR!' -or 
            ($_ -match 'error' -and $_ -notmatch '^(pnpm )?warn') 
        }
        
        if (-not $hasRealError) {
            Write-Ok "OpenClaw 安装完成"
            return $true
        } else {
            Write-Err "OpenClaw 安装失败：$($hasRealError[0])"
            return $false
        }
    } catch {
        Write-Err "OpenClaw 安装失败：$_"
        return $false
    }
}


function Step-Verify {
    Write-Step "步骤 5/5: 验证安装结果"
    
    # 刷新 PATH 环境变量（从注册表重新加载）
    Refresh-PathEnv
    Ensure-PnpmHome
    
    # 额外刷新：确保当前进程能立即使用新 PATH
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    try {
        $ver = (& openclaw -v 2>$null).Trim()
        if ($ver) {
            Write-Ok "OpenClaw $ver 安装成功！"
            Write-Host "`n  🦞 恭喜！你的龙虾已就位！`n" -ForegroundColor Green
            return $true
        }
    } catch {}
    
    Write-Err "安装完成但无法找到 openclaw 可执行文件"
    Write-Host "`n  请尝试以下步骤排查:" -ForegroundColor Yellow
    Write-Host "    1. 关闭当前终端，打开一个新的 PowerShell 窗口"
    Write-Host "    2. 运行 openclaw -v 检查是否可用"
    Write-Host "    3. 运行 pnpm bin -g 查看全局 bin 目录"
    Write-Host "    4. 将输出的目录手动添加到系统 PATH 环境变量"
    return $false
}

# ── 主函数 ──
function Main {
    Write-Host ""
    Write-Host "  🦞 OpenClaw 一键安装脚本" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    
    Refresh-PathEnv
    
    # 检测是否已安装
    $existingVer = try { & openclaw -v 2>$null } catch { $null }
    if ($existingVer) {
        Write-Ok "OpenClaw $existingVer 已安装，无需重复安装"
        Write-Host "`n  🦞 你的龙虾已就位！`n" -ForegroundColor Green
        return
    }
    
    if (-not (Step-CheckNode))       { Write-Host "`n  按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-CheckGit))        { Write-Host "`n  按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-InstallPnpm))     { Write-Host "`n  按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-InstallOpenClaw)) { Write-Host "`n  按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    if (-not (Step-Verify))          { Write-Host "`n  按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    
    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  🦞 安装完成！" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "  接下来请运行 openclaw onboard 进行配置" -ForegroundColor Cyan
    Write-Host ""
}

Main

# 安装完成后刷新当前进程的 PATH
Refresh-PathEnv