#
# OpenClaw 卸载脚本 (Windows)
# 用法：powershell -ExecutionPolicy Bypass -File uninstall-openclaw.ps1
#

# ── 强制 UTF-8 编码（解决中文乱码）──
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ── 执行策略自修复 ──
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

$ErrorActionPreference = "SilentlyContinue"
$ConfirmPreference = "None"

# ── 颜色输出 ──
function Write-Info { param($Msg) Write-Host "  [INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Ok   { param($Msg) Write-Host "  [OK]   " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn { param($Msg) Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err  { param($Msg) Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Step { param($Msg) Write-Host "`n━━━ $Msg ━━━`n" -ForegroundColor Cyan }

# ── 全局变量 ──
$OpenClawDirs = @()
$ConfigDirs = @()
$UninstallMode = "custom"  # minimal | custom | full

function Get-LocalAppData {
    if ($env:LOCALAPPDATA) { return $env:LOCALAPPDATA }
    return (Join-Path $HOME "AppData\Local")
}

# ── 查找 OpenClaw 安装位置 ──
function Find-OpenClaw {
    Write-Step "步骤 1/5: 查找 OpenClaw 安装位置"
    
    $searchDirs = @()
    
    # pnpm 全局 bin 目录
    $pnpmHome = $env:PNPM_HOME
    if (-not $pnpmHome) {
        $pnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    }
    if (Test-Path $pnpmHome) { $searchDirs += $pnpmHome }
    
    # pnpm global 子目录
    $pnpmGlobalDir = Join-Path $pnpmHome "global"
    if (Test-Path $pnpmGlobalDir) {
        Get-ChildItem -Path $pnpmGlobalDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $binDir = Join-Path $_.FullName "node_modules\.bin"
            if (Test-Path $binDir) { $searchDirs += $binDir }
        }
    }
    
    # npm 全局目录
    if ($env:APPDATA) {
        $appDataNpm = Join-Path $env:APPDATA "npm"
        if (Test-Path $appDataNpm) { $searchDirs += $appDataNpm }
    }
    
    # Node.js 目录
    $nodeDir = Join-Path (Get-LocalAppData) "nodejs"
    if (Test-Path $nodeDir) { $searchDirs += $nodeDir }
    
    # 使用 where.exe 查找
    try {
        $whereResult = & where.exe openclaw 2>$null
        if ($whereResult) {
            $whereResult -split "`r?`n" | ForEach-Object {
                $line = $_.Trim()
                if ($line -and (Test-Path $line)) {
                    $searchDirs += (Split-Path $line -Parent)
                }
            }
        }
    } catch {}
    
    # 在搜索目录中查找 openclaw 文件
    foreach ($dir in $searchDirs) {
        foreach ($name in @("openclaw.cmd", "openclaw.exe", "openclaw.ps1")) {
            $candidate = Join-Path $dir $name
            if (Test-Path $candidate) {
                Write-Ok "找到 OpenClaw: $candidate"
                $script:OpenClawDirs += $dir
                return $true
            }
        }
    }
    
    Write-Warn "未找到 OpenClaw 可执行文件"
    return $false
}

# ── 查找配置目录 ──
function Find-ConfigDirs {
    Write-Step "步骤 2/5: 查找配置和数据目录"
    
    # 用户目录下的 .openclaw
    $userConfig = Join-Path $HOME ".openclaw"
    if (Test-Path $userConfig) {
        Write-Ok "找到配置目录：$userConfig"
        $script:ConfigDirs += $userConfig
    }
    
    # LocalAppData 下的 openclaw
    $localData = Join-Path (Get-LocalAppData) "openclaw"
    if (Test-Path $localData) {
        Write-Ok "找到数据目录：$localData"
        $script:ConfigDirs += $localData
    }
    
    if ($script:ConfigDirs.Count -eq 0) {
        Write-Info "未找到配置目录"
    }
}

# ── 停止 OpenClaw 服务 ──
function Stop-OpenClawServices {
    Write-Step "步骤 3/5: 停止 OpenClaw 服务"
    
    # 查找并终止 openclaw 进程
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*openclaw*" }
    if ($processes) {
        Write-Info "正在停止 OpenClaw 进程..."
        foreach ($proc in $processes) {
            try {
                Stop-Process -Id $proc.Id -Force
                Write-Ok "已终止进程：$($proc.Name) (PID: $($proc.Id))"
            } catch {
                Write-Warn "无法终止进程：$($proc.Name)"
            }
        }
    } else {
        Write-Info "未发现运行中的 OpenClaw 进程"
    }
    
    # 查找并终止 node 进程（如果是 OpenClaw 启动的）
    $nodeProcesses = Get-Process | Where-Object { 
        $_.ProcessName -eq "node" -and 
        $_.CommandLine -like "*openclaw*" 
    } 2>$null
    if ($nodeProcesses) {
        Write-Info "正在停止 Node.js OpenClaw 进程..."
        foreach ($proc in $nodeProcesses) {
            try {
                Stop-Process -Id $proc.Id -Force
                Write-Ok "已终止 Node 进程 (PID: $($proc.Id))"
            } catch {
                Write-Warn "无法终止 Node 进程"
            }
        }
    }
}

# ── 卸载 OpenClaw ──
function Uninstall-OpenClaw {
    Write-Step "步骤 4/5: 卸载 OpenClaw"
    
    if ($script:OpenClawDirs.Count -eq 0) {
        Write-Warn "未找到 OpenClaw 安装目录，跳过卸载"
        return
    }
    
    # 尝试使用 pnpm 卸载
    $pnpmCmd = "pnpm"
    $pnpmHome = $env:PNPM_HOME
    if (-not $pnpmHome) {
        $pnpmHome = Join-Path (Get-LocalAppData) "pnpm"
    }
    $pnpmExe = Join-Path $pnpmHome "pnpm.cmd"
    if (Test-Path $pnpmExe) { $pnpmCmd = $pnpmExe }
    
    Write-Info "正在使用 pnpm 卸载 OpenClaw..."
    try {
        & $pnpmCmd remove -g openclaw 2>&1 | Out-Null
        Write-Ok "已通过 pnpm 卸载 OpenClaw"
    } catch {
        Write-Warn "pnpm 卸载失败，将手动删除文件"
    }
    
    # 手动删除剩余文件
    Write-Info "正在清理剩余文件..."
    foreach ($dir in $script:OpenClawDirs) {
        foreach ($name in @("openclaw.cmd", "openclaw.exe", "openclaw.ps1", "openclaw")) {
            $file = Join-Path $dir $name
            if (Test-Path $file) {
                try {
                    Remove-Item -Path $file -Force
                    Write-Ok "已删除：$file"
                } catch {
                    Write-Warn "无法删除：$file"
                }
            }
        }
    }
}

# ── 清理配置和数据 ──
function Cleanup-Config {
    Write-Step "步骤 5/5: 清理配置和数据"
    
    if ($script:ConfigDirs.Count -eq 0) {
        Write-Info "无需清理配置目录"
        return
    }
    
    Write-Warn "以下目录将被删除："
    foreach ($dir in $script:ConfigDirs) {
        Write-Host "    - $dir" -ForegroundColor Yellow
    }
    Write-Host ""
    
    $confirm = Read-Host "是否确认删除这些目录？[y/N]"
    if ($confirm -notmatch "^[Yy]") {
        Write-Info "已跳过配置目录删除"
        return
    }
    
    foreach ($dir in $script:ConfigDirs) {
        if (Test-Path $dir) {
            try {
                Remove-Item -Path $dir -Recurse -Force
                Write-Ok "已删除：$dir"
            } catch {
                Write-Warn "无法删除：$dir（可能有文件正在使用）"
            }
        }
    }
}

# ── 选择卸载模式 ──
function Select-UninstallMode {
    Write-Step "选择卸载模式"
    
    $localAppData = Get-LocalAppData
    $nodeDir = Join-Path $localAppData "nodejs"
    $pnpmHome = $env:PNPM_HOME
    if (-not $pnpmHome) {
        $pnpmHome = Join-Path $localAppData "pnpm"
    }
    
    $hasNode = Test-Path $nodeDir
    $hasPnpm = Test-Path $pnpmHome
    
    Write-Host "请选择卸载模式：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) 精简卸载 - 只卸载 OpenClaw，保留 Node.js、pnpm、Git"
    Write-Host "  2) 自定义卸载 - 逐项选择要删除的内容"
    if ($hasNode -or $hasPnpm) {
        Write-Host "  3) 全量卸载 - 删除所有（OpenClaw + Node.js + pnpm + 配置）"
    }
    Write-Host ""
    
    $maxOption = 2
    if ($hasNode -or $hasPnpm) { $maxOption = 3 }
    
    $modeChoice = Read-Host "请输入选项 [1-$maxOption]"
    
    switch ($modeChoice) {
        "1" {
            $script:UninstallMode = "minimal"
            Write-Ok "已选择：精简卸载"
        }
        "2" {
            $script:UninstallMode = "custom"
            Write-Ok "已选择：自定义卸载"
        }
        "3" {
            if ($maxOption -eq 3) {
                $script:UninstallMode = "full"
                Write-Ok "已选择：全量卸载"
            } else {
                Write-Warn "无效选项，将使用自定义模式"
                $script:UninstallMode = "custom"
            }
        }
        default {
            Write-Warn "无效选项，将使用自定义模式"
            $script:UninstallMode = "custom"
        }
    }
}

# ── 清理环境变量 ──
function Cleanup-Env {
    Write-Step "清理环境变量"
    
    # 从用户 PATH 中移除 openclaw 相关路径
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath) {
        $originalPath = $userPath
        $dirsToRemove = @()
        
        foreach ($dir in $script:OpenClawDirs) {
            if ($userPath -like "*$dir*") {
                $dirsToRemove += $dir
            }
        }
        
        foreach ($dir in $dirsToRemove) {
            $userPath = $userPath -replace [regex]::Escape("$dir;"), ""
            $userPath = $userPath -replace [regex]::Escape(";$dir"), ""
            $userPath = $userPath -replace [regex]::Escape($dir), ""
        }
        
        if ($userPath -ne $originalPath) {
            [Environment]::SetEnvironmentVariable("PATH", $userPath, "User")
            Write-Ok "已从用户 PATH 中清理 OpenClaw 路径"
        }
    }
    
    # 根据卸载模式决定是否删除 Node.js 和 pnpm
    Write-Host ""
    
    $localAppData = Get-LocalAppData
    $nodeDir = Join-Path $localAppData "nodejs"
    $pnpmHome = $env:PNPM_HOME
    if (-not $pnpmHome) {
        $pnpmHome = Join-Path $localAppData "pnpm"
    }
    
    if ($script:UninstallMode -eq "full") {
        # 全量模式：直接删除
        if (Test-Path $nodeDir) {
            Write-Info "全量卸载模式：正在删除 Node.js..."
            try {
                Remove-Item -Path $nodeDir -Recurse -Force
                Write-Ok "已删除：$nodeDir"
            } catch {
                Write-Warn "无法删除：$nodeDir"
            }
        }
        
        if (Test-Path $pnpmHome) {
            Write-Info "全量卸载模式：正在删除 pnpm..."
            try {
                Remove-Item -Path $pnpmHome -Recurse -Force
                Write-Ok "已删除：$pnpmHome"
            } catch {
                Write-Warn "无法删除：$pnpmHome"
            }
        }
        
    } elseif ($script:UninstallMode -eq "custom") {
        # 自定义模式：逐项询问
        if (Test-Path $nodeDir) {
            Write-Warn "检测到脚本安装的 Node.js: $nodeDir"
            $cleanNode = Read-Host "是否删除此目录？[y/N]"
            if ($cleanNode -match "^[Yy]") {
                try {
                    Remove-Item -Path $nodeDir -Recurse -Force
                    Write-Ok "已删除：$nodeDir"
                } catch {
                    Write-Warn "无法删除：$nodeDir"
                }
            }
        }
        
        if (Test-Path $pnpmHome) {
            Write-Warn "检测到 pnpm 目录：$pnpmHome"
            $cleanPnpm = Read-Host "是否删除此目录？[y/N]"
            if ($cleanPnpm -match "^[Yy]") {
                try {
                    Remove-Item -Path $pnpmHome -Recurse -Force
                    Write-Ok "已删除：$pnpmHome"
                } catch {
                    Write-Warn "无法删除：$pnpmHome"
                }
            }
        }
        
    } else {
        # 精简模式：保留
        Write-Info "精简卸载模式：保留 Node.js 和 pnpm"
    }
}

# ── 主函数 ──
function Main {
    Write-Host ""
    Write-Host "  🦞 OpenClaw 卸载脚本" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    
    # 检查是否已安装
    $existingVer = try { & openclaw -v 2>$null } catch { $null }
    if (-not $existingVer) {
        Write-Warn "未检测到 OpenClaw，可能已经卸载"
        $force = Read-Host "是否继续清理配置目录？[y/N]"
        if ($force -notmatch "^[Yy]") {
            Write-Host ""
            Write-Host "  已取消卸载" -ForegroundColor Yellow
            Write-Host ""
            return
        }
    } else {
        Write-Info "当前版本：OpenClaw $existingVer"
    }
    
    Write-Host ""
    Write-Warn "警告：此操作将卸载 OpenClaw 并删除所有配置数据！"
    Write-Host ""
    
    $confirm = Read-Host "是否确认继续？[y/N]"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host ""
        Write-Host "  已取消卸载" -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    Write-Host ""
    
    # 选择卸载模式
    Select-UninstallMode
    
    Find-OpenClaw | Out-Null
    Find-ConfigDirs | Out-Null
    Stop-OpenClawServices
    Uninstall-OpenClaw
    Cleanup-Config
    Cleanup-Env
    
    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  🦞 卸载完成！" -ForegroundColor Green
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Info "建议：关闭当前终端并重新打开，以确保环境变量生效"
    Write-Host ""
}

Main

# 刷新当前进程的 PATH
$machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH = "$userPath;$machinePath"
