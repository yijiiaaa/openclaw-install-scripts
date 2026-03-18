#!/usr/bin/env bash
#
# OpenClaw 卸载脚本 (macOS / Linux)
# 用法：bash uninstall-openclaw.sh
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
OPENCLAW_DIRS=()
CONFIG_DIRS=()
UNINSTALL_MODE="custom"  # minimal | custom | full

# ── 查找 OpenClaw 安装位置 ──
find_openclaw() {
    step "步骤 1/5: 查找 OpenClaw 安装位置"
    
    local found=false
    
    # 在 PATH 中查找
    if command -v openclaw &>/dev/null; then
        local openclaw_path
        openclaw_path=$(command -v openclaw)
        success "找到 OpenClaw: $openclaw_path"
        OPENCLAW_DIRS+=("$(dirname "$openclaw_path")")
        found=true
    fi
    
    # 检查 pnpm 全局目录
    local pnpm_home="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    if [[ -d "$pnpm_home" ]]; then
        local pnpm_openclaw="$pnpm_home/openclaw"
        if [[ -d "$pnpm_openclaw" ]]; then
            success "找到 pnpm 安装目录：$pnpm_openclaw"
            OPENCLAW_DIRS+=("$pnpm_openclaw")
            found=true
        fi
    fi
    
    # 检查 npm 全局目录
    if command -v npm &>/dev/null; then
        local npm_global
        npm_global=$(npm prefix -g 2>/dev/null || true)
        if [[ -n "$npm_global" ]]; then
            local npm_openclaw="$npm_global/lib/node_modules/openclaw"
            if [[ -d "$npm_openclaw" ]]; then
                success "找到 npm 安装目录：$npm_openclaw"
                OPENCLAW_DIRS+=("$npm_openclaw")
                found=true
            fi
        fi
    fi
    
    if [[ "$found" == "false" ]]; then
        warn "未找到 OpenClaw 可执行文件"
        return 1
    fi
    
    return 0
}

# ── 查找配置目录 ──
find_config_dirs() {
    step "步骤 2/5: 查找配置和数据目录"
    
    # 用户目录下的 .openclaw
    if [[ -d "$HOME/.openclaw" ]]; then
        success "找到配置目录：$HOME/.openclaw"
        CONFIG_DIRS+=("$HOME/.openclaw")
    fi
    
    # Local 数据目录
    local local_data=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        local_data="$HOME/Library/Application Support/openclaw"
    else
        # Linux
        local_data="${XDG_DATA_HOME:-$HOME/.local/share}/openclaw"
    fi
    
    if [[ -d "$local_data" ]]; then
        success "找到数据目录：$local_data"
        CONFIG_DIRS+=("$local_data")
    fi
    
    if [[ ${#CONFIG_DIRS[@]} -eq 0 ]]; then
        info "未找到配置目录"
    fi
}

# ── 停止 OpenClaw 服务 ──
stop_openclaw_services() {
    step "步骤 3/5: 停止 OpenClaw 服务"
    
    # 获取当前脚本 PID，避免误杀自己
    local my_pid=$$
    
    # 查找并终止 openclaw 进程（排除当前脚本）
    local pids
    pids=$(pgrep -f "openclaw" 2>/dev/null | grep -v "^${my_pid}$" || true)
    if [[ -n "$pids" ]]; then
        info "正在停止 OpenClaw 进程..."
        for pid in $pids; do
            if kill -9 "$pid" 2>/dev/null; then
                success "已终止进程 (PID: $pid)"
            else
                warn "无法终止进程 (PID: $pid)"
            fi
        done
    else
        info "未发现运行中的 OpenClaw 进程"
    fi
    
    # 查找并终止 node 进程（如果是 OpenClaw 启动的，排除当前脚本）
    local node_pids
    node_pids=$(pgrep -f "node.*openclaw" 2>/dev/null | grep -v "^${my_pid}$" || true)
    if [[ -n "$node_pids" ]]; then
        info "正在停止 Node.js OpenClaw 进程..."
        for pid in $node_pids; do
            if kill -9 "$pid" 2>/dev/null; then
                success "已终止 Node 进程 (PID: $pid)"
            else
                warn "无法终止 Node 进程 (PID: $pid)"
            fi
        done
    fi
}

# ── 卸载 OpenClaw ──
uninstall_openclaw() {
    step "步骤 4/5: 卸载 OpenClaw"
    
    if [[ ${#OPENCLAW_DIRS[@]} -eq 0 ]]; then
        warn "未找到 OpenClaw 安装目录，跳过卸载"
        return
    fi
    
    # 尝试使用 pnpm 卸载
    if command -v pnpm &>/dev/null; then
        info "正在使用 pnpm 卸载 OpenClaw..."
        if pnpm remove -g openclaw 2>&1; then
            success "已通过 pnpm 卸载 OpenClaw"
        else
            warn "pnpm 卸载失败，将手动删除文件"
        fi
    fi
    
    # 尝试使用 npm 卸载
    if command -v npm &>/dev/null; then
        info "正在使用 npm 卸载 OpenClaw..."
        if npm uninstall -g openclaw 2>&1; then
            success "已通过 npm 卸载 OpenClaw"
        else
            warn "npm 卸载失败，将手动删除文件"
        fi
    fi
    
    # 手动删除剩余文件
    info "正在清理剩余文件..."
    for dir in "${OPENCLAW_DIRS[@]}"; do
        for name in openclaw openclaw.cmd openclaw.ps1; do
            local file="$dir/$name"
            if [[ -f "$file" ]]; then
                if rm -f "$file" 2>/dev/null; then
                    success "已删除：$file"
                else
                    warn "无法删除：$file"
                fi
            fi
        done
    done
}

# ── 清理配置和数据 ──
cleanup_config() {
    step "步骤 5/5: 清理配置和数据"
    
    if [[ ${#CONFIG_DIRS[@]} -eq 0 ]]; then
        info "无需清理配置目录"
        return
    fi
    
    warn "以下目录将被删除："
    for dir in "${CONFIG_DIRS[@]}"; do
        echo -e "    ${YELLOW}- $dir${NC}"
    done
    echo ""
    
    read -rp "是否确认删除这些目录？[y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        info "已跳过配置目录删除"
        return
    fi
    
    for dir in "${CONFIG_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            if rm -rf "$dir" 2>/dev/null; then
                success "已删除：$dir"
            else
                warn "无法删除：$dir（可能有文件正在使用）"
            fi
        fi
    done
}

# ── 选择卸载模式 ──
select_uninstall_mode() {
    step "选择卸载模式"
    
    local node_dir="$HOME/.local/node"
    local pnpm_home="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    local has_node=false
    local has_pnpm=false
    
    [[ -d "$node_dir" ]] && has_node=true
    [[ -d "$pnpm_home" ]] && has_pnpm=true
    
    echo "请选择卸载模式："
    echo ""
    echo "  1) 精简卸载 - 只卸载 OpenClaw，保留 Node.js、pnpm、Git"
    echo "  2) 自定义卸载 - 逐项选择要删除的内容"
    if [[ "$has_node" == "true" ]] || [[ "$has_pnpm" == "true" ]]; then
        echo "  3) 全量卸载 - 删除所有（OpenClaw + Node.js + pnpm + 配置）"
    fi
    echo ""
    
    local max_option=2
    [[ "$has_node" == "true" ]] || [[ "$has_pnpm" == "true" ]] && max_option=3
    
    read -rp "请输入选项 [1-$max_option]： " mode_choice
    
    case "$mode_choice" in
        1)
            UNINSTALL_MODE="minimal"
            success "已选择：精简卸载"
            ;;
        2)
            UNINSTALL_MODE="custom"
            success "已选择：自定义卸载"
            ;;
        3)
            if [[ $max_option -eq 3 ]]; then
                UNINSTALL_MODE="full"
                success "已选择：全量卸载"
            else
                warn "无效选项，将使用自定义模式"
                UNINSTALL_MODE="custom"
            fi
            ;;
        *)
            warn "无效选项，将使用自定义模式"
            UNINSTALL_MODE="custom"
            ;;
    esac
}

# ── 清理环境变量 ──
cleanup_env() {
    step "清理环境变量"
    
    local node_dir="$HOME/.local/node"
    local pnpm_home="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    
    # 自动从 shell 配置中移除安装脚本添加的 PATH
    local profiles=()
    if [[ -f "$HOME/.zshrc" ]]; then profiles+=("$HOME/.zshrc"); fi
    if [[ -f "$HOME/.bash_profile" ]]; then profiles+=("$HOME/.bash_profile"); fi
    if [[ -f "$HOME/.bashrc" ]]; then profiles+=("$HOME/.bashrc"); fi
    if [[ -f "$HOME/.profile" ]]; then profiles+=("$HOME/.profile"); fi
    
    local removed=false
    for profile in "${profiles[@]}"; do
        if [[ -f "$profile" ]] && grep -q "OpenClaw 安装脚本添加" "$profile" 2>/dev/null; then
            info "正在清理 $profile 中的 PATH 配置..."
            # 创建备份
            cp "$profile" "$profile.openclaw.bak"
            # 删除标记行和后续两行（PATH 配置）
            sed -i.bak '/OpenClaw 安装脚本添加/,+2d' "$profile"
            rm -f "$profile.bak" 2>/dev/null || true
            success "已清理：$profile"
            removed=true
        fi
    done
    
    if [[ "$removed" == "true" ]]; then
        success "已自动清理 shell 配置中的 PATH"
        info "建议执行 'source ~/.zshrc' 或重新打开终端使配置生效"
    fi
    
    # 根据卸载模式决定是否删除 Node.js 和 pnpm
    echo ""
    
    if [[ "$UNINSTALL_MODE" == "full" ]]; then
        # 全量模式：直接删除
        if [[ -d "$node_dir" ]]; then
            info "全量卸载模式：正在删除 Node.js..."
            if rm -rf "$node_dir" 2>/dev/null; then
                success "已删除：$node_dir"
            else
                warn "无法删除：$node_dir"
            fi
        fi
        
        if [[ -d "$pnpm_home" ]]; then
            info "全量卸载模式：正在删除 pnpm..."
            if rm -rf "$pnpm_home" 2>/dev/null; then
                success "已删除：$pnpm_home"
            else
                warn "无法删除：$pnpm_home"
            fi
        fi
        
    elif [[ "$UNINSTALL_MODE" == "custom" ]]; then
        # 自定义模式：逐项询问
        if [[ -d "$node_dir" ]]; then
            warn "检测到脚本安装的 Node.js: $node_dir"
            read -rp "是否删除此目录？[y/N] " clean_node
            if [[ "$clean_node" =~ ^[Yy] ]]; then
                if rm -rf "$node_dir" 2>/dev/null; then
                    success "已删除：$node_dir"
                else
                    warn "无法删除：$node_dir"
                fi
            fi
        fi
        
        if [[ -d "$pnpm_home" ]]; then
            warn "检测到 pnpm 目录：$pnpm_home"
            read -rp "是否删除此目录？[y/N] " clean_pnpm
            if [[ "$clean_pnpm" =~ ^[Yy] ]]; then
                if rm -rf "$pnpm_home" 2>/dev/null; then
                    success "已删除：$pnpm_home"
                else
                    warn "无法删除：$pnpm_home"
                fi
            fi
        fi
    else
        # 精简模式：保留
        info "精简卸载模式：保留 Node.js 和 pnpm"
    fi
}

# ── 交互式输入支持 ──
HAS_TTY=false
if [[ -t 0 ]]; then
    HAS_TTY=true
elif [[ -e /dev/tty ]]; then
    HAS_TTY=true
fi

prompt_read() {
    local var_name="$1"
    local prompt_text="$2"
    local default_val="${3:-}"
    if [[ "$HAS_TTY" == "true" ]]; then
        if [[ -t 0 ]]; then
            read -rp "$prompt_text" "$var_name"
        else
            read -rp "$prompt_text" "$var_name" < /dev/tty
        fi
    else
        warn "非交互模式，无法读取用户输入"
        printf -v "$var_name" '%s' "$default_val"
    fi
}

# ── 主函数 ──
main() {
    echo ""
    echo -e "${GREEN}🦞 OpenClaw 卸载脚本${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 检查是否已安装
    local existing_ver
    existing_ver=$(openclaw -v 2>/dev/null || true)
    if [[ -z "$existing_ver" ]]; then
        warn "未检测到 OpenClaw，可能已经卸载"
        echo ""
        read -rp "是否继续清理配置目录？[y/N] " force
        if [[ ! "$force" =~ ^[Yy] ]]; then
            echo ""
            echo -e "  ${YELLOW}已取消卸载${NC}"
            echo ""
            return 0
        fi
    else
        info "当前版本：OpenClaw $existing_ver"
    fi
    
    echo ""
    warn "警告：此操作将卸载 OpenClaw 并删除所有配置数据！"
    echo ""
    
    read -rp "是否确认继续？[y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo ""
        echo -e "  ${YELLOW}已取消卸载${NC}"
        echo ""
        return 0
    fi
    
    echo ""
    
    # 选择卸载模式
    select_uninstall_mode
    
    find_openclaw || true
    find_config_dirs
    stop_openclaw_services
    uninstall_openclaw
    cleanup_config
    cleanup_env
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🦞 卸载完成！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    info "建议：关闭当前终端并重新打开，以确保环境变量生效"
    echo ""
}

main "$@"
