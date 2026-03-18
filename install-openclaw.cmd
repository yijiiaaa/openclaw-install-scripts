@echo off
chcp 65001 >nul 2>&1

echo.
echo ========================================
echo    OpenClaw Install Script
echo ========================================
echo.

REM Check if OpenClaw is already installed
echo [Info] Checking if OpenClaw is already installed...

REM Method 1: Try openclaw -v command (most reliable)
set OC_INSTALLED=0
set OC_VER=
openclaw -v >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('openclaw -v 2^>nul') do set OC_VER=%%i
    set OC_INSTALLED=1
    echo [Info] Found OpenClaw via command: %OC_VER%
)

REM Method 2: Check pnpm global bin directory
if %OC_INSTALLED% equ 0 (
    if exist "%LOCALAPPDATA%\pnpm\global\node_modules\.bin\openclaw.cmd" (
        set OC_INSTALLED=1
        echo [Info] Found OpenClaw in pnpm global bin
    )
)

REM Method 3: Check npm global directory
if %OC_INSTALLED% equ 0 (
    if exist "%APPDATA%\npm\openclaw.cmd" (
        set OC_INSTALLED=1
        echo [Info] Found OpenClaw in npm global
    )
)

REM Method 4: Check PNPM_HOME if set
if %OC_INSTALLED% equ 0 (
    if defined PNPM_HOME (
        if exist "%PNPM_HOME%\openclaw.cmd" (
            set OC_INSTALLED=1
            echo [Info] Found OpenClaw in PNPM_HOME
        )
    )
)

if %OC_INSTALLED% equ 1 (
    echo.
    echo ========================================
    if defined OC_VER (
        echo    OpenClaw %OC_VER% is already installed!
    ) else (
        echo    OpenClaw is already installed!
    )
    echo ========================================
    echo.
    echo If you want to reinstall, please uninstall first:
    echo   uninstall-openclaw.cmd
    echo.
    echo Or run: pnpm remove -g openclaw
    echo.
    pause
    exit /b 0
)

echo [Info] OpenClaw not found, proceeding with installation...

echo [Step 1/5] Checking Node.js...
node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo [Error] Node.js not found
    echo Download: https://nodejs.org/
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node -v') do set NODE_VER=%%i
echo [OK] Node.js %NODE_VER% installed

REM Get actual node.exe path from running process (first match only)
for /f "delims=" %%i in ('where node 2^>nul') do (
    if not defined NODE_PATH set NODE_PATH=%%i
)
if defined NODE_PATH (
    for %%i in ("%NODE_PATH%") do set NODE_DIR=%%~dpi
) else (
    set NODE_DIR=
)

echo.
echo [Step 2/5] Checking Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [Error] Git not found
    echo Download: https://git-scm.com/
    pause
    exit /b 1
)
for /f "tokens=3" %%i in ('git --version') do set GIT_VER=%%i
echo [OK] Git %GIT_VER% installed

echo.
echo [Step 3/5] Checking pnpm...

REM Try multiple pnpm locations
set PNPM=
if defined NODE_DIR (
    if exist "%NODE_DIR%pnpm.cmd" set PNPM=%NODE_DIR%pnpm.cmd
)
if not defined PNPM (
    call npm config get prefix >nul 2>&1
    for /f "delims=" %%i in ('npm config get prefix 2^>nul') do set NPM_PREFIX=%%i
    if defined NPM_PREFIX (
        if exist "%NPM_PREFIX%\pnpm.cmd" set PNPM=%NPM_PREFIX%\pnpm.cmd
    )
)
if not defined PNPM (
    if exist "%APPDATA%\npm\pnpm.cmd" set PNPM=%APPDATA%\npm\pnpm.cmd
)
if not defined PNPM (
    where pnpm.cmd >nul 2>&1
    if not errorlevel 1 (
        for /f "delims=" %%i in ('where pnpm.cmd 2^>nul') do (
            if not defined PNPM set PNPM=%%i
        )
    )
)

if defined PNPM (
    for /f "tokens=*" %%i in ('%PNPM% -v 2^>nul') do set PNPM_VER=%%i
    if defined PNPM_VER (
        echo [OK] pnpm %PNPM_VER% already installed
    ) else (
        set PNPM=
    )
)

if not defined PNPM (
    echo [Info] Installing pnpm...
    call npm install -g pnpm --registry=https://registry.npmmirror.com
    if %errorlevel% neq 0 (
        echo [Error] pnpm install failed
        pause
        exit /b 1
    )
    REM Refresh and find pnpm
    call npm config get prefix >nul 2>&1
    for /f "delims=" %%i in ('npm config get prefix 2^>nul') do set NPM_PREFIX=%%i
    set PNPM=%NPM_PREFIX%\pnpm.cmd
    if not exist "%PNPM%" (
        if defined NODE_DIR set PNPM=%NODE_DIR%pnpm.cmd
    )
    if not exist "%PNPM%" set PNPM=pnpm.cmd
    for /f "tokens=*" %%i in ('%PNPM% -v 2^>nul') do set PNPM_VER=%%i
    echo [OK] pnpm %PNPM_VER% installed
)

echo.
echo [Step 4/5] Configuring registry...
call npm config set registry https://registry.npmmirror.com
echo [OK] Registry configured

echo.
echo [Step 5/5] Installing OpenClaw...
echo [Info] Please wait, this may take a few minutes...

REM Try pnpm first, fallback to npm
call %PNPM% install -g openclaw@latest --registry=https://registry.npmmirror.com
if %errorlevel% neq 0 (
    echo [Warn] pnpm install failed, trying npm...
    call npm install -g openclaw@latest --registry=https://registry.npmmirror.com
    if %errorlevel% neq 0 (
        echo.
        echo [Error] OpenClaw install failed
        echo Try running manually: npm install -g openclaw@latest
        pause
        exit /b 1
    )
)
echo [OK] OpenClaw installed

echo.
echo ========================================
echo    Verifying...
echo ========================================
openclaw -v >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('openclaw -v') do set OC_VER=%%i
    echo [OK] OpenClaw %OC_VER% installed
    echo.
    echo ========================================
    echo    Success!
    echo ========================================
    echo.
    echo Next: Run 'openclaw onboard'
) else (
    echo [Warn] Verify failed, restart terminal and try: openclaw -v
)

echo.
pause
