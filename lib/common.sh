# 公共：路径、颜色、宽度/框打印、版本

PROFILES_DIR="$HOME/.claude/model-profiles"
SETTINGS_FILE="$HOME/.claude/settings.json"
STATE_FILE="$HOME/.claude/.current-model-profile"

INSTALL_DIR="${CSWITCH_HOME:-$HOME/.cswitch}"
BIN_DIR="$HOME/.local/bin"

# GitHub 仓库（建仓后若改名只需改这一处）
REPO="${CSWITCH_REPO:-zeno528/cswitch}"
RAW_BASE="${CSWITCH_RAW_BASE:-https://raw.githubusercontent.com/$REPO/main}"
TARBALL_URL="${CSWITCH_TARBALL_URL:-https://codeload.github.com/$REPO/tar.gz/refs/heads/main}"

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
TITLE='\033[38;2;63;174;194m'  # #3faec2
BOLD='\033[1m'
NC='\033[0m'

# 全局统一输出：图标固定占 2 列，文本从同一列开始对齐
# 用法: say "✅" "文本"（带图标） / say "" "文本"（无图标）
say() {
    local icon="$1" text="$2"
    if [[ -n "$icon" ]]; then
        printf '%b\n' "  $icon $text"
    else
        printf '%b\n' "     $text"
    fi
}

# 本地版本（读取 VERSION 文件，缺失按 0.0.0）
app_version() {
    local v
    v=$(python3 -c "import json;print(json.load(open('$APP_DIR/VERSION'))['message'])" 2>/dev/null)
    [[ -n "$v" ]] && { echo "$v"; return; }
    cat "$APP_DIR/VERSION" 2>/dev/null || echo "0.0.0"
}

# 远端版本（GitHub raw VERSION）
remote_version() {
    curl -fsSL -m 8 "$RAW_BASE/VERSION" 2>/dev/null | python3 -c "
import json, sys
d = sys.stdin.read().strip()
print(json.loads(d)['message'] if d.startswith('{') else d)
" 2>/dev/null
}

# $1 > $2
version_gt() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" != "$1" ]]
}

# 终端显示宽度（CJK 按 2 列）
str_width() {
    python3 -c "
import unicodedata,sys
s=sys.argv[1]
print(sum(2 if unicodedata.east_asian_width(c) in('W','F') else 1 for c in s))
" "$1"
}

print_dash() {
    local w="$1" i
    for ((i = 0; i < w; i++)); do printf "─"; done
}

# box_line <content> <target_w> [gut]：gut 为内容左侧固定 2 列标记位
box_line() {
    local content="$1" target_w="$2" gut="${3:-  }" cw pad clean
    clean=$(echo "$content" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')
    cw=$(str_width "$clean")
    pad=$((target_w - cw))
    printf "  ${CYAN}│${NC} %s  %b%*s   ${CYAN}│${NC}\n" "$gut" "$content" $pad ""
}

# 打开 profile 目录：WSL 用资源管理器，其他 Linux 打印路径
open_profiles_dir() {
    if command -v explorer.exe >/dev/null 2>&1; then
        explorer.exe "$(wslpath -w "$PROFILES_DIR")"
    else
        echo "  📂 $PROFILES_DIR"
    fi
}
