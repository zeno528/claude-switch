# shellcheck shell=bash
# Claude Code 安装/升级模块
#
# 功能:
#   - 未安装 → 官方安装器 (curl -fsSL https://claude.ai/install.sh | bash)
#   - 已安装 → 对比 GitHub Releases 最新版本，有新版才升级
#
# 参数（跟随主命令: cswitch claude [--info|-y|-s|-f]）

# macOS 无 timeout 命令
command -v timeout >/dev/null 2>&1 || timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

# 检测 Claude Code 安装方式（官方安装器 native / Homebrew brew / npm-已废弃）
# 依据官方文档: 原生装在 ~/.local/bin，brew 装 /opt/homebrew 或 /usr/local，npm 在全局 node_modules
claude_install_method() {
    local bin_path bin_real npm_root
    bin_path=$(command -v claude 2>/dev/null) || return 1
    if command -v brew >/dev/null 2>&1; then
        brew list --cask claude-code >/dev/null 2>&1 && { echo "brew"; return; }
        brew list --cask claude-code@latest >/dev/null 2>&1 && { echo "brew-latest"; return; }
    fi
    if command -v npm >/dev/null 2>&1; then
        npm_root=$(npm root -g 2>/dev/null)
        bin_real=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$bin_path" 2>/dev/null)
        [[ -n "$npm_root" && "$bin_real" == "$npm_root"* ]] && { echo "npm"; return; }
    fi
    echo "native"
}

cmd_claude_upgrade() {
    local YES_MODE=false INFO_MODE=false SILENT=false FORCE=false arg
    for arg in "$@"; do
        [[ "$arg" == "--yes" || "$arg" == "-y" ]] && YES_MODE=true
        [[ "$arg" == "--info" ]] && INFO_MODE=true
        [[ "$arg" == "--silent" || "$arg" == "-s" ]] && SILENT=true
        [[ "$arg" == "--force" || "$arg" == "-f" ]] && FORCE=true
    done

    local RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
    local step_n=0
    print_step() { step_n=$((step_n + 1)); echo -e "\n${YELLOW}🔍 [$step_n]${NC} $1"; }
    print_ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
    print_fail() { echo -e "  ${RED}❌ $1${NC}"; }
    print_info() { echo -e "  ${CYAN}➜${NC} $1"; }

    str_width() {
        python3 -c "
import unicodedata,sys,re
s=sys.argv[1]
s=re.sub(r'(?:\x1b|\\\\033)\[[0-9;]*m','',s)
print(sum(2 if unicodedata.east_asian_width(c) in('W','F') else 1 for c in s))
" "$1"
    }
    print_card() {
        local title="$1" W="${2:-42}"
        shift 2
        local pad fill="" line spaces=""
        local header="─ ${title} "
        pad=$(( W - $(str_width "$header") ))
        for ((i = 0; i < pad; i++)); do fill+="─"; done
        echo -e "  ${CYAN}╭${header}${fill}╮${NC}"
        while [[ $# -ge 2 ]]; do
            line="  $1  $2"
            shift 2
            pad=$(( W - $(str_width "$line") ))
            spaces=""
            for ((i = 0; i < pad; i++)); do spaces+=" "; done
            echo -e "  ${CYAN}│${NC}${line}${spaces}${CYAN}│${NC}"
        done
        local dash=""
        for ((i = 0; i < W; i++)); do dash+="─"; done
        echo -e "  ${CYAN}╰${dash}╯${NC}"
    }
    print_title() {
        local text="$1" W="${2:-42}" dash="" pad spaces=""
        for ((i = 0; i < W; i++)); do dash+="─"; done
        pad=$(( W - $(str_width "$text") ))
        for ((i = 0; i < pad; i++)); do spaces+=" "; done
        echo -e "  ${CYAN}╭${dash}╮${NC}"
        echo -e "  ${CYAN}│${NC}${text}${spaces}${CYAN}│${NC}"
        echo -e "  ${CYAN}╰${dash}╯${NC}"
    }

    claude_exists() { command -v claude &>/dev/null; }

    get_local_version() {
        claude --version 2>/dev/null | awk '{print $1}' || echo "unknown"
    }

    get_latest_version() {
        curl -sf -m 15 "https://api.github.com/repos/anthropics/claude-code/releases/latest" \
            | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name','').lstrip('v'))" 2>/dev/null \
            || echo "unknown"
    }

    install_method_label() {
        case "$1" in
            brew) echo "Homebrew (claude-code cask)" ;;
            brew-latest) echo "Homebrew (claude-code@latest cask)" ;;
            npm) echo "npm 全局包（已废弃）" ;;
            *) echo "官方安装器 (~/.local/bin/)" ;;
        esac
    }

    # ── Info 模式 ──
    if $INFO_MODE; then
        if ! claude_exists; then
            echo -e "${RED}❌ Claude Code 未安装${NC}  运行 ${GREEN}cswitch claude${NC} 自动安装"
            return 1
        fi
        local_version=$(get_local_version)
        install_method=$(claude_install_method)
        echo ""
        print_title "  🤖 Claude Code"
        echo -e "  版本    ${GREEN}$local_version${NC}"
        echo -e "  路径    $(command -v claude)"
        echo -e "  方式    $(install_method_label "$install_method")"
        if [[ "$install_method" == "npm" ]]; then
            echo -e "  ${YELLOW}⚠️  npm 安装已被官方废弃，建议迁移到官方安装器:${NC}"
            echo -e "  ${GREEN}    curl -fsSL https://claude.ai/install.sh | bash${NC}"
        fi
        echo -e "  状态    ${GREEN}✅ 运行正常${NC}"
        return 0
    fi

    $SILENT || {
        echo ""
        print_title "  🤖 Claude Code  (官方安装/升级器)"
    }
    local START_TIME
    START_TIME=$(date +%s)

    # ── 环境检查 ──
    $SILENT || print_step "环境检查"
    if ! command -v curl &>/dev/null; then
        print_fail "需要 curl"; return 1
    fi
    $SILENT || print_ok "curl 可用"

    local MODE=""
    if ! claude_exists; then
        MODE="install"
        $SILENT || print_info "📥 Claude Code 未安装，进入安装模式 (官方安装器)"
        $SILENT || echo ""
        $SILENT || print_step "下载并执行官方安装器"
        curl -fsSL https://claude.ai/install.sh | bash
        $SILENT || print_ok "安装完成"
    else
        MODE="upgrade"
        current_version=$(get_local_version)
        $SILENT || print_ok "已安装版本: $current_version 📦"

        install_method=$(claude_install_method)
        $SILENT || print_ok "安装方式: $(install_method_label "$install_method")"

        # native: 对比 GitHub Releases 决定是否升级；brew: 交给包管理器（cask 有发布滞后，自比较不准确）
        if [[ "$install_method" == "npm" ]]; then
            print_fail "npm 安装已被官方废弃，不支持通过 cswitch 升级"
            print_info "迁移到官方安装器: ${GREEN}curl -fsSL https://claude.ai/install.sh | bash${NC}"
            return 1
        elif [[ "$install_method" == "native" ]]; then
            $SILENT || print_step "检查最新版本 (GitHub Releases)"
            latest_version=$(get_latest_version)

            if [[ "$current_version" == "$latest_version" && "$FORCE" == "false" ]]; then
                $SILENT || { print_ok "已是最新版本 ($current_version) — 来源: GitHub官方仓库 ✨"; echo ""; print_card "🏷️ Claude Code" 42 "版本" "${GREEN}$current_version${NC}" "状态" "✅ 已是最新 (GitHub Releases)"; }
                return 0
            fi

            if $FORCE; then
                $SILENT || print_info "⚡ 强制升级模式"
            fi

            if [[ "$latest_version" != "unknown" ]]; then
                $SILENT || echo -e "  🔔 ${CYAN}$current_version${NC} → ${CYAN}$latest_version${NC}"
            fi
            $SILENT || echo ""

            $SILENT || print_step "确认升级"
            if $YES_MODE; then
                confirm="Y"
                $SILENT || print_ok "自动确认"
            else
                read -rp "  升级 Claude Code？(Y/n,回车默认 Y): " confirm
                confirm=${confirm:-Y}
            fi
            [[ "$confirm" != "Y" && "$confirm" != "y" ]] && { echo -e "  ${YELLOW}已取消${NC}"; return 0; }

            $SILENT || print_step "执行升级"
            claude update </dev/null >/dev/null 2>&1 || true
        else
            # brew：包管理器自行判断是否有新版（幂等，已最新则无操作）
            $SILENT || print_step "执行升级 ($(install_method_label "$install_method"))"
            if $YES_MODE; then
                $SILENT || print_info "⚡ 自动确认"
            else
                read -rp "  升级 Claude Code？(Y/n,回车默认 Y): " confirm
                confirm=${confirm:-Y}
            fi
            [[ "$confirm" != "Y" && "$confirm" != "y" ]] && { echo -e "  ${YELLOW}已取消${NC}"; return 0; }

            local cask="claude-code"
            [[ "$install_method" == "brew-latest" ]] && cask="claude-code@latest"
            brew upgrade "$cask"
        fi
    fi

    # ── 验证 ──
    if ! claude_exists && [[ -f "$HOME/.local/bin/claude" ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if claude_exists; then
        new_version=$(get_local_version)
        if [[ "$MODE" == "install" ]]; then
            $SILENT || { echo ""; print_card "🏷️ Claude Code" 42 "版本" "${GREEN}$new_version${NC}" "状态" "✅ 安装成功"; echo ""; }
        fi
    else
        print_fail "安装失败"; return 1
    fi

    $SILENT || {
        END_TS=$(date +%s)
        ELAPSED=$((END_TS - START_TIME))
        MINUTES=$((ELAPSED / 60))
        SECONDS=$((ELAPSED % 60))
        echo ""
        if [[ "$MODE" == "upgrade" && "$current_version" != "$new_version" ]]; then
            print_card "🏷️ Claude Code" 42 "升级前" "${GREEN}$current_version${NC}" "升级后" "${GREEN}$new_version${NC}" "状态" "✅ 升级成功" "耗时" "${MINUTES}分${SECONDS}秒"
        elif [[ "$MODE" == "upgrade" ]]; then
            print_card "🏷️ Claude Code" 42 "当前版本" "${GREEN}$new_version${NC}" "状态" "⚠️ 版本未变化" "耗时" "${MINUTES}分${SECONDS}秒"
        fi
        echo ""
    }
}
