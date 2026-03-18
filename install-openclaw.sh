#!/usr/bin/env bash
#
# OpenClaw 一键安装脚本 (macOS / Linux)
# 用法：bash install-openclaw.sh
#

set -euo pipefail

# ── 强制 UTF-8 编码（解决中文乱码）──
export LANG=en_US.UTF-8 2>/dev/null || export LANG=C.UTF-8 2>/dev/null || true
export LC_ALL=en_US.UTF-8 2>/dev/null || export LC_ALL=C.UTF-8 2>/dev/null || true

# ── 颜色输出 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ ${NC}$*"; }
success() { echo -e "${GREEN}✅ ${NC}$*"; }
warn()    { echo -e "${YELLOW}⚠️  ${NC}$*"; }
error()   { echo -e "${RED}❌ ${NC}$*"; }
step()    { echo -e "\n${CYAN}━━━ $* ━━━${NC}\n"; }

# ── 全局变量 ──
REQUIRED_NODE_MAJOR=22
ARCH=$(uname -m)
case "$ARCH" in
  arm64|aarch64) ARCH="arm64" ;;
  *)             ARCH="x64" ;;
esac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# ── PATH 扩展 ──
ensure_path() {
  local dirs=(/opt/homebrew/bin /usr/local/bin)
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] && [[ ":$PATH:" != *":$d:"* ]] && export PATH="$d:$PATH" || true
  done
}

# ── Node.js 版本检测 ──
check_node_version() {
  local cmd="${1:-node}"
  local ver
  ver=$("$cmd" -v 2>/dev/null || true)
  if [[ "$ver" =~ v([0-9]+) ]]; then
    local major="${BASH_REMATCH[1]}"
    if (( major >= REQUIRED_NODE_MAJOR )); then
      echo "$ver"
      return 0
    fi
  fi
  return 1
}

# ── 下载工具 ──
download_file() {
  local dest="$1"
  shift
  for url in "$@"; do
    local host
    host=$(echo "$url" | sed 's|https\?://\([^/]*\).*|\1|')
    info "正在从 $host 下载..."
    if curl -fsSL --connect-timeout 30 --retry 3 --retry-delay 2 --max-time 300 -o "$dest" "$url" 2>/dev/null; then
      success "下载完成"
      return 0
    fi
    warn "从 $host 下载失败，尝试备用源..."
  done
  return 1
}

# ── 安装 Node.js ──
install_node_direct() {
  info "正在直接下载安装 Node.js v22..."
  
  local version="v22.16.0"
  local os_name
  [[ "$OS" == "darwin" ]] && os_name="darwin" || os_name="linux"
  local filename="node-${version}-${os_name}-${ARCH}.tar.gz"
  local tmp_path
  tmp_path=$(mktemp -d)
  local tmp_file="$tmp_path/$filename"
  
  if ! download_file "$tmp_file" \
    "https://npmmirror.com/mirrors/node/${version}/${filename}" \
    "https://nodejs.org/dist/${version}/${filename}"; then
    error "Node.js 下载失败，请检查网络连接"
    rm -rf "$tmp_path"
    return 1
  fi
  
  local installed=false
  local user_dir="$HOME/.local/node"
  info "正在安装到用户目录 $user_dir..."
  mkdir -p "$user_dir"
  
  # 先解压到临时目录，再移动文件（更可靠）
  local extract_dir="$tmp_path/extract"
  mkdir -p "$extract_dir"
  if tar -xzf "$tmp_file" -C "$extract_dir"; then
    # 查找解压后的目录
    local node_dir
    node_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "node-*" | head -1)
    if [[ -n "$node_dir" ]]; then
      # 复制文件到目标目录
      cp -r "$node_dir"/* "$user_dir/"
      export PATH="$user_dir/bin:$PATH"
      installed=true
      success "Node.js 已安装到 $user_dir"
    else
      error "无法找到解压后的 Node.js 目录"
    fi
  fi
  
  rm -rf "$tmp_path"
  
  [[ "$installed" == "false" ]] && return 1
  
  local ver
  ver=$(check_node_version) && {
    success "Node.js $ver 已可用"
    return 0
  }
  warn "Node.js 安装完成但验证失败"
  return 1
}

# ── 安装 Git ──
check_git_version() {
  git --version 2>/dev/null
}

install_git_mac() {
  local brew_path=""
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$p" ]] && brew_path="$p" && break
  done
  
  if [[ -n "$brew_path" ]]; then
    info "检测到 Homebrew，正在使用 brew 安装 Git..."
    if "$brew_path" install git; then
      check_git_version &>/dev/null && { success "Git 已通过 Homebrew 安装"; return 0; }
    fi
  fi
  
  info "正在通过 Xcode Command Line Tools 安装 Git..."
  xcode-select --install 2>/dev/null || true
  check_git_version &>/dev/null && { success "Git 已安装"; return 0; }
  return 1
}

install_git_linux() {
  info "正在安装 Git..."
  if command -v apt-get &>/dev/null; then
    info "检测到 apt-get，正在安装..."
    sudo apt-get update && sudo apt-get install -y git && { success "Git 安装成功"; return 0; }
  elif command -v dnf &>/dev/null; then
    info "检测到 dnf，正在安装..."
    sudo dnf install -y git && { success "Git 安装成功"; return 0; }
  elif command -v yum &>/dev/null; then
    info "检测到 yum，正在安装..."
    sudo yum install -y git && { success "Git 安装成功"; return 0; }
  elif command -v pacman &>/dev/null; then
    info "检测到 pacman，正在安装..."
    sudo pacman -S --noconfirm git && { success "Git 安装成功"; return 0; }
  fi
  return 1
}

# ── 主流程步骤 ──
step_check_node() {
  step "步骤 1/4: 准备 Node.js 环境"
  ensure_path
  
  local ver
  if ver=$(check_node_version); then
    success "Node.js $ver 已安装，版本满足要求 (>= 22)"
    return 0
  fi
  
  local existing_ver
  existing_ver=$(node -v 2>/dev/null || true)
  if [[ -n "$existing_ver" ]]; then
    warn "检测到 Node.js ${existing_ver}，版本过低，需要 v22 以上"
  else
    warn "未检测到 Node.js"
  fi
  
  info "正在自动安装 Node.js v22..."
  install_node_direct && return 0
  
  error "安装失败，请检查网络连接后重试"
  return 1
}

step_check_git() {
  step "步骤 2/4: 准备 Git 环境"
  
  if check_git_version &>/dev/null; then
    success "$(git --version 2>/dev/null || echo 'Git') 已安装"
    return 0
  fi
  
  warn "未检测到 Git，正在自动安装..."
  
  if [[ "$OS" == "darwin" ]]; then
    install_git_mac && return 0
  else
    install_git_linux && return 0
  fi
  
  error "Git 自动安装失败，请手动安装 Git 后重试"
  echo "  下载地址：https://git-scm.com/downloads"
  return 1
}

step_install_openclaw() {
  step "步骤 3/4: 安装 OpenClaw"
  info "正在安装 OpenClaw，请耐心等待..."
  
  # 配置 git 使用 HTTPS 而不是 SSH（避免 SSH 密钥问题）
  git config --global url."https://github.com/".insteadOf ssh://git@github.com/ 2>/dev/null || true
  
  # 使用 npmmirror 镜像源（国内更快，且避免 GitHub SSH 问题）
  export NPM_CONFIG_REGISTRY="https://registry.npmmirror.com"
  
  # 优先使用 pnpm（如果已安装）
  if command -v pnpm &>/dev/null; then
    info "检测到 pnpm，使用 pnpm 安装..."
    if pnpm add -g openclaw@latest 2>&1; then
      success "OpenClaw 已通过 pnpm 安装完成"
      return 0
    fi
    warn "pnpm 安装失败，尝试使用 npm..."
  fi
  
  # 检查 npm 是否可用
  if ! command -v npm &>/dev/null; then
    error "未找到 npm，请先安装 Node.js"
    return 1
  fi
  
  if npm install -g openclaw@latest 2>&1; then
    success "OpenClaw 安装完成"
    return 0
  fi
  
  error "OpenClaw 安装失败"
  echo ""
  echo "  可能的原因和解决方案："
  echo "    1. 网络问题 - 检查网络连接后重试"
  echo "    2. Git 未配置 - 运行 'git config --global user.email' 配置邮箱"
  echo "    3. 手动安装 - 运行：npm install -g openclaw@latest"
  return 1
}

step_verify() {
  step "步骤 4/4: 验证安装结果"
  ensure_path
  
  local ver
  ver=$(openclaw -v 2>/dev/null || true)
  
  if [[ -n "$ver" ]]; then
    success "OpenClaw $ver 安装成功！"
    echo -e "\n${GREEN}🦞 恭喜！你的龙虾已就位！${NC}\n"
    return 0
  fi
  
  warn "未能验证 OpenClaw 安装，请尝试重新打开终端后执行 openclaw -v"
  return 0
}

# ── 添加 PATH 到 shell 配置 ──
add_to_shell_config() {
  local node_bin="$HOME/.local/node/bin"
  local pnpm_home="$HOME/.local/share/pnpm"
  local pnpm_bin="$pnpm_home"
  
  # pnpm 的 bin 目录可能在 ~/.local/share/pnpm 或 ~/.pnpm-core-sdk/bin
  # 先检测 pnpm 实际安装位置
  if command -v pnpm &>/dev/null; then
    local pnpm_path
    pnpm_path=$(command -v pnpm)
    pnpm_bin=$(dirname "$pnpm_path")
  fi
  
  # 检测 shell 类型（使用 ${VAR:-} 语法避免未定义变量报错）
  local shell_config=""
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ -f "$HOME/.zshrc" ]]; then
    shell_config="$HOME/.zshrc"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ -f "$HOME/.bashrc" ]]; then
    shell_config="$HOME/.bashrc"
  elif [[ -f "$HOME/.bash_profile" ]]; then
    shell_config="$HOME/.bash_profile"
  fi
  
  if [[ -n "$shell_config" ]]; then
    info "正在配置 PATH 到 $shell_config ..."
    
    # 检查是否有写入权限
    if [[ ! -w "$shell_config" ]]; then
      warn "没有权限写入 $shell_config（可能是之前用 sudo 运行导致文件属于 root）"
      echo ""
      echo -e "${YELLOW}解决方案：${NC}"
      echo ""
      echo "  方法 1：修复文件权限（推荐）"
      echo -e "    ${CYAN}sudo chown \$USER:\$USER $shell_config${NC}"
      echo ""
      echo "  方法 2：手动添加以下行到 $shell_config"
      echo -e "    ${CYAN}echo 'export PATH=\"$node_bin:\$PATH\"' >> $shell_config${NC}"
      echo -e "    ${CYAN}echo 'export PATH=\"$pnpm_bin:\$PATH\"' >> $shell_config${NC}"
      echo ""
      echo "  方法 3：临时在当前会话生效"
      echo -e "    ${CYAN}export PATH=\"$node_bin:$pnpm_bin:\$PATH${NC}"
      echo ""
      
      # 尝试使用 sudo 修复权限
      if [[ -t 0 ]]; then
        read -rp "是否使用 sudo 修复文件权限？[y/N] " fix_perm
        if [[ "$fix_perm" =~ ^[Yy] ]]; then
          if sudo chown "$USER:$USER" "$shell_config" 2>/dev/null; then
            success "已修复文件权限"
          else
            warn "修复权限失败，请手动执行上述命令"
          fi
        fi
      fi
    fi
    
    # 检查是否已存在
    if ! grep -q "node/bin" "$shell_config" 2>/dev/null; then
      # 尝试写入配置
      local write_result=0
      cat >> "$shell_config" << EOF 2>/dev/null || write_result=$?

# OpenClaw 安装脚本添加 - $(date '+%Y-%m-%d %H:%M:%S')
export PATH="$node_bin:\$PATH"
export PATH="$pnpm_bin:\$PATH"
EOF
      if [[ $write_result -eq 0 ]]; then
        success "已将 Node.js 和 pnpm 添加到 PATH"
      else
        warn "无法写入配置文件，请手动添加 PATH 配置"
      fi
    else
      info "PATH 配置已存在，跳过"
    fi
    
    # 同时尝试添加到 .profile（某些系统登录时读取）
    if [[ -f "$HOME/.profile" ]] && [[ -w "$HOME/.profile" ]] && ! grep -q "node/bin" "$HOME/.profile" 2>/dev/null; then
      cat >> "$HOME/.profile" << EOF

# OpenClaw 安装脚本添加 - $(date '+%Y-%m-%d %H:%M:%S')
export PATH="$node_bin:\$PATH"
export PATH="$pnpm_bin:\$PATH"
EOF
    fi
    
    success "请执行 'source $shell_config' 或重新打开终端使配置生效"
    
    # 同时更新当前 shell 会话的 PATH（这样脚本后续步骤可以立即使用）
    export PATH="$node_bin:$pnpm_bin:$PATH"
  fi
}

# ── 主函数 ──
main() {
  echo ""
  echo -e "${GREEN}🦞 OpenClaw 一键安装脚本${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # 检测是否使用 sudo 运行
  if [[ $EUID -eq 0 ]]; then
    error "检测到使用 sudo 运行，这会导致安装到 root 用户！"
    echo ""
    echo -e "${YELLOW}⚠️  请使用普通用户运行此脚本（不要用 sudo）${NC}"
    echo ""
    echo "  正确用法："
    echo -e "    ${CYAN}bash install-openclaw.sh${NC}"
    echo ""
    echo "  如果需要安装到系统目录，请手动安装 Node.js 后，脚本会自动使用系统 Node.js"
    echo ""
    exit 1
  fi
  
  # 检测是否已安装
  ensure_path
  local existing_ver
  existing_ver=$(openclaw -v 2>/dev/null || true)
  if [[ -n "$existing_ver" ]]; then
    success "OpenClaw $existing_ver 已安装，无需重复安装"
    echo -e "\n${GREEN}🦞 你的龙虾已就位！${NC}\n"
    return 0
  fi
  
  step_check_node || exit 1
  step_check_git || exit 1
  step_install_openclaw || exit 1
  
  # 添加 PATH 到 shell 配置
  add_to_shell_config
  
  step_verify || exit 1
  
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}🦞 安装完成！${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}⚠️  重要：请执行以下命令使 node 和 openclaw 命令生效：${NC}"
  echo ""
  echo -e "    ${CYAN}source ~/.zshrc${NC}"
  echo ""
  echo -e "  或者关闭当前终端，重新打开一个新窗口${NC}"
  echo ""
  echo -e "  然后运行：${CYAN}openclaw onboard${NC}"
  echo ""
}

main "$@"
