@echo off
chcp 65001 >nul 2>&1

echo.
echo ========================================
echo    OpenClaw 卸载脚本
echo ========================================
echo.

echo [信息] 检测 OpenClaw 安装状态...
openclaw -v >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('openclaw -v') do set OC_VER=%%i
    echo [成功] 检测到 OpenClaw %OC_VER%
) else (
    echo [警告] 未检测到 OpenClaw
    set /p FORCE=是否继续清理配置？[y/N]: 
    if /i not "%FORCE%"=="y" (
        echo 已取消
        pause
        exit /b 0
    )
)

echo.
echo [警告] 此操作将卸载 OpenClaw 并删除配置数据
set /p CONFIRM=是否确认？[y/N]: 
if /i not "%CONFIRM%"=="y" (
    echo 已取消
    pause
    exit /b 0
)

echo.
echo 选择卸载模式:
echo   1 ^) 精简卸载 - 只卸载 OpenClaw
echo   2 ^) 完全卸载 - 删除 OpenClaw + 配置
set /p MODE=请输入选项 [1-2]: 
if "%MODE%"=="2" (
    set FULL_UNINSTALL=1
) else (
    set FULL_UNINSTALL=0
)

echo.
echo [信息] 停止 OpenClaw 进程...
taskkill /F /IM openclaw.exe >nul 2>&1
echo [成功] 已尝试停止进程

echo.
echo [信息] 正在卸载 OpenClaw...

REM Find pnpm location
set PNPM_CMD=
if exist "%APPDATA%\npm\pnpm.cmd" set PNPM_CMD=%APPDATA%\npm\pnpm.cmd
if not defined PNPM_CMD (
    where pnpm.cmd >nul 2>&1
    if not errorlevel 1 (
        for /f "delims=" %%i in ('where pnpm.cmd 2^>nul') do (
            if not defined PNPM_CMD set PNPM_CMD=%%i
        )
    )
)
if not defined PNPM_CMD set PNPM_CMD=pnpm.cmd

call %PNPM_CMD% remove -g openclaw >nul 2>&1
if %errorlevel% equ 0 (
    echo [成功] 已通过 pnpm 卸载
) else (
    echo [信息] pnpm 卸载失败，将手动清理
)

if "%FULL_UNINSTALL%"=="1" (
    echo.
    echo [信息] 清理配置文件中...
    if exist "%USERPROFILE%\.openclaw" (
        rmdir /s /q "%USERPROFILE%\.openclaw" 2>nul
        echo [成功] 已删除：%USERPROFILE%\.openclaw
    )
    if exist "%LOCALAPPDATA%\openclaw" (
        rmdir /s /q "%LOCALAPPDATA%\openclaw" 2>nul
        echo [成功] 已删除：%LOCALAPPDATA%\openclaw
    )
) else (
    echo.
    echo [信息] 精简模式，保留配置
)

echo.
echo ========================================
echo    卸载完成
echo ========================================
echo.
echo [提示] 建议重启终端
echo.

pause
