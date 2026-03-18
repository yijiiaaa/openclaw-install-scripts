# OpenClaw 一键安装/卸载脚本

本目录包含 OpenClaw 的一键安装和卸载脚本，支持 Windows、macOS 和 Linux 平台。

> 🦞 **龙虾已就位！** 5 分钟内完成 OpenClaw 部署，让你的 AI 助手随时待命。

---

## 📦 文件说明

| 文件 | 适用平台 | 大小 | 说明 |
|------|---------|------|------|
| `install-openclaw.ps1` | Windows | 13 KB | PowerShell 安装脚本（5 步流程） |
| `install-openclaw.sh` | macOS / Linux | 12 KB | Bash 安装脚本（4 步流程） |
| `uninstall-openclaw.ps1` | Windows | 15 KB | PowerShell 卸载脚本（3 种模式） |
| `uninstall-openclaw.sh` | macOS / Linux | 14 KB | Bash 卸载脚本（3 种模式） |
| `README.md` | 全部 | 9 KB | 本文档 |

---

## 🚀 快速开始

### Windows (PowerShell)

**安装：**

```powershell
powershell -ExecutionPolicy Bypass -File install-openclaw.ps1
```

**中文乱码时改用：**

```powershell
& {$w=New-Object Net.WebClient;$w.Encoding=[Text.Encoding]::UTF8;Invoke-Expression $w.DownloadString((Get-Item .\install-openclaw.ps1).FullName)}
```

**卸载：**

```powershell
powershell -ExecutionPolicy Bypass -File uninstall-openclaw.ps1
```

**中文乱码时改用：**

```
& {$w=New-Object Net.WebClient;$w.Encoding=[Text.Encoding]::UTF8;Invoke-Expression $w.DownloadString((Get-Item .\install-openclaw.ps1).FullName)}
```

---

### macOS / Linux (Bash)

**安装：**
```bash
bash install-openclaw.sh
```

> ⚠️ **重要：不要使用 sudo 运行！** 脚本会以当前用户身份安装，使用 sudo 会导致安装到 root 用户，普通用户无法使用。

**卸载：**
```bash
bash uninstall-openclaw.sh
```

---

## 📋 系统要求

| 组件 | 要求 | 说明 |
|------|------|------|
| 操作系统 | Windows 10+ / macOS 10.15+ / Linux | 主流发行版均可 |
| Node.js | v22+ | 脚本会自动安装 |
| Git | 任意版本 | 用于依赖解析，脚本会自动安装 |
| 磁盘空间 | 约 500MB | 包含 Node.js、pnpm 和 OpenClaw |
| 网络连接 | 需要访问 npm 镜像 | 脚本使用国内镜像源 |

---

## 🔧 安装流程

### Windows (5 步)

| 步骤 | 说明 |
|------|------|
| 1/5 | 检测/安装 Node.js v22+（OpenClaw 要求） |
| 2/5 | 检测/安装 Git（用于依赖解析） |
| 3/5 | 安装 pnpm（Node.js 包管理器） |
| 4/5 | 安装 OpenClaw CLI |
| 5/5 | 验证安装结果 |

### macOS / Linux (4 步)

| 步骤 | 说明 |
|------|------|
| 1/4 | 检测/安装 Node.js v22+（OpenClaw 要求） |
| 2/4 | 检测/安装 Git（用于依赖解析） |
| 3/4 | 安装 OpenClaw CLI（自动配置 npm/pnpm） |
| 4/4 | 验证安装结果 + 配置 PATH |

> 💡 **安装完成后**，macOS/Linux 用户需要执行 `source ~/.zshrc` 或重新打开终端使 PATH 生效。

---

## 🗑️ 卸载流程

卸载脚本提供 **3 种模式**，可根据需求选择：

### 模式对比

| 模式 | 删除内容 | 适用场景 |
|------|---------|---------|
| **精简卸载** | 仅 OpenClaw | 想保留 Node.js、pnpm，可能重新安装 |
| **自定义卸载** | 逐项选择 | 想精细控制删除内容 |
| **全量卸载** | 所有（OpenClaw + Node.js + pnpm + 配置） | 彻底清理，不再使用 |

### 卸载步骤

| 步骤 | 说明 |
|------|------|
| 1/5 | 查找 OpenClaw 安装位置 |
| 2/5 | 查找配置和数据目录 |
| 3/5 | 停止运行中的 OpenClaw 进程 |
| 4/5 | 使用 pnpm/npm 卸载并清理文件 |
| 5/5 | 清理配置目录和环境变量 |

> ⚠️ **警告：** 卸载会删除所有配置数据（包括 API Key 和本地设置）。如需保留，请提前备份 `~/.openclaw` 目录。

---

## ⚙️ 安装后配置

安装完成后，运行以下命令进行初始化配置：

```bash
openclaw onboard
```

配置向导会引导你完成：
1. 选择 AI 厂商（OpenAI、Anthropic、Gemini、智谱、月之暗面等）
2. 输入 API Key
3. 选择默认模型
4. 启动 OpenClaw 服务

---

## 🔍 常见问题

### 1. PowerShell 执行策略错误 (Windows)

**症状：** 无法运行脚本，提示执行策略限制

**解决方案：**
```powershell
# 临时绕过（推荐）
powershell -ExecutionPolicy Bypass -File install-openclaw.ps1

# 或永久修改（仅当前用户）
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

### 2. 中文乱码 (Windows)

**症状：** 控制台输出中文显示为乱码

**解决方案：**

**方法一：** 使用 UTF-8 编码方式执行

```powershell
& {$w=New-Object Net.WebClient;$w.Encoding=[Text.Encoding]::UTF8;Invoke-Expression $w.DownloadString((Get-Item .\install-openclaw.ps1).FullName)}
```

**方法二：** 在 PowerShell 7+ 中执行（默认 UTF-8）
```powershell
pwsh -ExecutionPolicy Bypass -File install-openclaw.ps1
```

---

### 3. Node.js 版本过低

**症状：** 检测到 Node.js 但版本低于 v22

**解决方案：** 脚本会自动安装 Node.js v22。如果失败，请手动安装：
- Windows: https://nodejs.org/
- macOS: `brew install node@22`
- Linux: 使用包管理器安装

---

### 3.1. 安装后 node/openclaw 命令找不到

**症状：** 安装完成后，运行 `node -v` 或 `openclaw -v` 提示 `command not found`

**原因 1：** PATH 环境变量已写入配置文件，但当前终端会话尚未加载

**解决方案：**

```bash
# 方法 1：执行 source 命令（推荐）
source ~/.zshrc   # 或 source ~/.bashrc

# 方法 2：关闭当前终端，重新打开一个新窗口
```

然后验证：
```bash
node -v
openclaw -v
```

**原因 2：** 使用 sudo 运行了安装脚本，导致安装到了 root 用户

**症状：** 安装时看到 `正在安装到用户目录 /root/.local/node`

**解决方案：**
```bash
# 1. 清理 root 用户的安装（可选）
sudo bash uninstall-openclaw.sh

# 2. 使用普通用户重新安装（不要用 sudo）
bash install-openclaw.sh

# 3. 安装完成后执行 source
source ~/.zshrc
```

**原因 3：** `.bashrc` 或 `.zshrc` 文件权限问题（无法写入）

**症状：** 安装时看到 `Permission denied` 错误

**解决方案：**
```bash
# 方法 1：修复文件权限（推荐）
sudo chown $USER:$USER ~/.bashrc
# 或者对于 zsh
sudo chown $USER:$USER ~/.zshrc

# 方法 2：手动添加 PATH 配置
echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/share/pnpm:$PATH"' >> ~/.bashrc

# 方法 3：临时在当前会话生效
export PATH="$HOME/.local/node/bin:$HOME/.local/share/pnpm:$PATH"
```

然后执行：
```bash
source ~/.bashrc
node -v
openclaw -v
```

---

### 4. Git 未安装

**症状：** 未检测到 Git

**解决方案：** 脚本会自动安装 Git。如果失败，请手动安装：
- Windows: https://git-scm.com/downloads
- macOS: `xcode-select --install` 或 `brew install git`
- Linux: `sudo apt-get install git` 或使用对应包管理器

---

### 4.1. npm 安装时出现 Git SSH 权限错误

**症状：** 安装 OpenClaw 时出现以下错误：
```
npm error command git --no-replace-objects ls-remote ssh://git@github.com/...
npm error git@github.com: Permission denied (publickey).
```

**原因：** 某个 npm 依赖试图通过 SSH 访问 GitHub，但服务器未配置 SSH 密钥

**解决方案：** 脚本已自动处理，会：
1. 配置 git 使用 HTTPS 而不是 SSH
2. 使用 npmmirror 镜像源（避免 GitHub 访问问题）
3. 如果 npm 失败，自动尝试使用 pnpm 安装

如果仍然失败，可以手动执行：
```bash
# 配置 git 使用 HTTPS
git config --global url."https://github.com/".insteadOf ssh://git@github.com/

# 使用镜像源安装
npm config set registry https://registry.npmmirror.com
npm install -g openclaw@latest
```

---

### 5. openclaw 命令找不到

**症状：** 安装完成后，运行 `openclaw` 提示找不到命令

**解决方案：**
1. 关闭当前终端，打开新窗口
2. 运行 `openclaw -v` 检查
3. 如仍不可用，运行 `pnpm bin -g` 查看全局 bin 目录
4. 将该目录添加到 PATH 环境变量

---

### 6. 网络问题/下载失败

**症状：** 下载 Node.js、Git 或 OpenClaw 时失败

**解决方案：**
- 脚本已使用国内镜像源（npmmirror）
- 检查网络连接
- 如有代理，设置环境变量：
  ```bash
  export HTTP_PROXY=http://127.0.0.1:7890
  export HTTPS_PROXY=http://127.0.0.1:7890
  ```

---

### 7. 卸载时无法删除配置目录

**症状：** 卸载脚本提示无法删除某些文件

**解决方案：**
- 确保 OpenClaw 进程已完全停止
- 手动关闭可能占用文件的编辑器或终端
- 重启电脑后再次运行卸载脚本

---

### 8. 卸载后想重新安装

**解决方案：**
1. 运行卸载脚本，选择「全量卸载」彻底清理
2. 重新打开终端
3. 运行安装脚本重新安装

---

## 📝 环境变量

安装脚本会配置以下环境变量：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PNPM_HOME` | pnpm 全局安装目录 | `%LOCALAPPDATA%\pnpm` (Win) / `~/.local/share/pnpm` (Mac/Linux) |
| `PATH` | 添加 Node.js 和 pnpm 的 bin 目录 | 自动添加 |

**Windows:** 环境变量写入注册表（用户级别）  
**macOS/Linux:** 环境变量写入 `~/.zshrc` / `~/.bashrc` / `~/.profile`

---

## 🛠️ 手动安装（备选）

如果自动安装失败，可手动执行：

```bash
# 1. 确保 Node.js v22+ 已安装
node -v

# 2. 安装 pnpm
npm install -g pnpm

# 3. 安装 OpenClaw
pnpm add -g openclaw@latest

# 4. 验证
openclaw -v

# 5. 配置
openclaw onboard
```

---

## 🛠️ 手动卸载（备选）

如果自动卸载失败，可手动执行：

```bash
# 1. 停止 OpenClaw 进程
# Windows: 任务管理器中结束 openclaw 和 node 进程
# Mac/Linux: killall openclaw node

# 2. 卸载 OpenClaw
pnpm remove -g openclaw

# 3. 删除配置目录
# Windows: 删除 %USERPROFILE%\.openclaw 和 %LOCALAPPDATA%\openclaw
# Mac/Linux: rm -rf ~/.openclaw ~/.local/share/openclaw

# 4. 清理 PATH 环境变量
# 编辑 ~/.zshrc 或 ~/.bashrc，删除包含 openclaw 或 pnpm 的行
```

---

## 📞 获取帮助

| 资源 | 链接 |
|------|------|
| 官方文档 | https://docs.openclaw.ai |
| 社区 | https://discord.com/invite/clawd |
| GitHub | https://github.com/openclaw/openclaw |
| 问题反馈 | https://github.com/openclaw/openclaw/issues |

---

## ⚠️ 注意事项

1. **不要使用 sudo 运行安装脚本**（macOS/Linux）- 会导致安装到 root 用户
2. **管理员权限** - Windows 某些步骤可能需要管理员权限（Git 安装、PATH 修改等）
3. **网络连接** - 确保可以访问 npm 镜像和 GitHub
4. **磁盘空间** - 确保有足够的磁盘空间（约 500MB）
5. **防火墙** - 如使用企业网络，可能需要配置代理
6. **备份配置** - 卸载前请备份 `~/.openclaw` 目录（包含 API Key 和自定义配置）
7. **终端重启** - 安装/卸载后建议关闭当前终端并重新打开，确保环境变量生效

---

## 📜 脚本特性

### 安装脚本特性
- ✅ 自动检测并安装 Node.js v22+
- ✅ 自动检测并安装 Git
- ✅ 自动安装 pnpm 包管理器
- ✅ 使用国内镜像源（npmmirror），下载更快
- ✅ 自动配置 PATH 环境变量
- ✅ 强制 UTF-8 编码，避免中文乱码
- ✅ 详细的进度提示和错误信息

### 卸载脚本特性
- ✅ 3 种卸载模式（精简/自定义/全量）
- ✅ 自动查找并停止 OpenClaw 进程
- ✅ 自动清理环境变量
- ✅ 自动清理 shell 配置文件（macOS/Linux）
- ✅ 删除前确认，避免误操作
- ✅ 详细的清理报告

---

**🦞 祝使用愉快！**
