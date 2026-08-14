#!/usr/bin/env bash
# cswitch 功能冒烟测试：隔离 HOME 下验证核心链路（切换/向导/菜单/版本/安装）
# 用法: ./tests/smoke.sh
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" CSWITCH_HOME="$T/cswitch"

mkdir -p "$HOME/.claude/model-profiles" "$HOME/.claude"
printf '%s' '{"env":{}}' > "$HOME/.claude/settings.json"
printf '%s' '{"env":{"ANTHROPIC_MODEL":"deepseek"}}' > "$HOME/.claude/model-profiles/deepseek.json"
printf '%s' '{"env":{"ANTHROPIC_MODEL":"minimax"}}' > "$HOME/.claude/model-profiles/MiniMax.json"

pass=0 fail=0
run() { # run <desc> <bash 脚本>
    local desc="$1" script="$2"
    if APP_DIR="$APP_DIR" T="$T" bash -c "$script" >/dev/null 2>&1; then
        echo "  ✅ $desc"; pass=$((pass+1))
    else
        echo "  ❌ $desc"; fail=$((fail+1))
    fi
}

echo "[1] 基础冒烟"
run "cswitch version"          '"$APP_DIR/cswitch" version'
run "cswitch help"             '"$APP_DIR/cswitch" help'
run "菜单空输入正常退出"         'timeout 15 "$APP_DIR/cswitch" </dev/null'

echo "[2] 切换链路"
run "切换 deepseek 写入 settings/state" '
    source "$APP_DIR/lib/common.sh"
    source "$APP_DIR/lib/profile.sh"
    source "$APP_DIR/lib/switch.sh"
    do_switch deepseek false false
    grep -q ANTHROPIC_MODEL "$HOME/.claude/settings.json"
    [ "$(cat "$HOME/.claude/.current-model-profile")" = deepseek ]'
run "大小写不敏感切换 MiNiMaX" '
    source "$APP_DIR/lib/common.sh"
    source "$APP_DIR/lib/profile.sh"
    source "$APP_DIR/lib/switch.sh"
    do_switch MiNiMaX false false
    [ "$(cat "$HOME/.claude/.current-model-profile")" = MiniMax ]'
run "切换不存在的配置返回失败" '
    source "$APP_DIR/lib/common.sh"
    source "$APP_DIR/lib/profile.sh"
    source "$APP_DIR/lib/switch.sh"
    ! ( do_switch nonexist false false )'

echo "[3] 新建配置向导"
run "向导生成 testcfg.json" '
    source "$APP_DIR/lib/common.sh"
    source "$APP_DIR/lib/profile.sh"
    printf "testcfg\nhttps://api.example.com\nkey123\nmodel-x\n\n" | create_new_profile
    [ -f "$HOME/.claude/model-profiles/testcfg.json" ]'

echo "[4] 版本链路"
run "check-update 能检测远端" '
    source "$APP_DIR/lib/common.sh"
    source "$APP_DIR/lib/selfupdate.sh"
    cmd_check_update | grep -Eq "已是最新|发现新版本"'

echo "[5] 安装链路"
run "install.sh 安装 + 软链 + 版本解析" '
    HOME="$T/insthome" CSWITCH_HOME="$T/inst" "$APP_DIR/install.sh" >/dev/null
    [ -x "$T/inst/cswitch" ]
    [ -L "$T/insthome/.local/bin/cswitch" ]
    "$T/inst/cswitch" version | grep -q "cswitch v"'

echo
echo "通过 $pass 项，失败 $fail 项"
[[ $fail -eq 0 ]]
