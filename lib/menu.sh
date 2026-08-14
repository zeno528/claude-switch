# shellcheck shell=bash
# 交互菜单：显示当前配置 + profile 列表 + 用量，n/o/g 快捷键

# 交互动作完成后先停下确认，再决定回菜单还是启动 Claude
back_to_menu() {
    local ans
    echo ""
    printf '     下一步 · %bg%b 启动 Claude · 回车返回菜单: ' "$GREEN" "$NC"
    read -r ans
    ans=$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')
    [[ "$ans" == "g" ]] && exec claude
    exec "$0"
}

show_menu() {
    # 启动/重启时清屏，菜单始终从干净屏幕开始；清掉后补一行启动命令作上下文
    clear
    echo "  \$ $(basename "$0")"

    # 标题卡内容（嵌入边框左上角 + 版本号行）
    local ver_line ver_clean
    ver_line=" 版本  ${GREEN}v$(app_version)${NC}"
    local title_header="─ 🏷️ cswitch "

    # 收集 profile（带编号）
    local profile_names=() profile_lines=() profile_gutters=() idx=1
    for f in "$PROFILES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        pname=$(basename "$f" .json)
        profile_names+=("$pname")
        pdesc=$(profile_model "$f")
        [[ -z "$pdesc" ]] && pdesc="$pname"
        marker="  "
        [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "$pname" ]] && marker="🟢"
        profile_lines+=("${idx}) ${pname} — ${pdesc}")
        profile_gutters+=("$marker")
        ((idx++))
    done
    local total=${#profile_names[@]}

    # 并行查询用量（DeepSeek / 智谱 / MiniMax）
    printf "  ⏳ 正在查询用量..."
    local usage_lines=()
    while IFS='|' read -r k disp; do
        [[ -z "$k" ]] && continue
        usage_lines+=("$k|$disp")
    done < <(query_all_usage)

    # 擦除进度提示行
    printf "\r\033[2K"

    local hint_line1="新建配置：${BOLD}${GREEN}n${NC}  |  打开目录：${BOLD}${GREEN}o${NC}  |  升级：${BOLD}${GREEN}u${NC}  |  卸载：${BOLD}${GREEN}x${NC}"
    local hint_line2="Claude 安装/升级：${BOLD}${GREEN}c${NC}"

    # 计算最大显示宽度（含提示行，框宽自适应所有内容）
    local max_w=0 all_lines=("$ver_line" "${profile_lines[@]}" \
        "直接切换: cswitch <name> --go" "$hint_line1" "$hint_line2")
    for line in "${all_lines[@]}"; do
        clean=$(echo "$line" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')
        w=$(str_width "$clean")
        [[ $w -gt $max_w ]] && max_w=$w
    done
    (( max_w < 60 )) && max_w=60

    echo ""

    # 标题卡：╭─ 🏷️ cswitch ──╮ / │ 版本  v1.0.6 │ / ├──┤（标题嵌入左上角）
    local tw fill ver_pad spaces
    tw=$((max_w + 12))
    fill=""
    for ((i = 0; i < tw - 4 - $(str_width "$title_header"); i++)); do fill+="─"; done
    echo -e "  ${CYAN}╭${title_header}${fill}╮${NC}"
    ver_clean=$(echo "$ver_line" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')
    ver_pad=$((tw - 6 - $(str_width "$ver_clean")))
    spaces=""
    for ((i = 0; i < ver_pad; i++)); do spaces+=" "; done
    echo -e "  ${CYAN}│${NC} ${ver_line}${spaces} ${CYAN}│${NC}"
    echo -e "  ${CYAN}├$(print_dash $((max_w + 8)))┤${NC}"

    # profile 列表
    for idx in "${!profile_lines[@]}"; do
        pline="${profile_lines[$idx]}"
        box_line "$pline" "$max_w" "${profile_gutters[$idx]}"
        slug="${profile_names[$idx]}"
        u=""
        for line in "${usage_lines[@]}"; do
            [[ "$line" == "$(slug_provider "$slug")|"* ]] && u="${line#*|}" && break
        done
        if [[ -n "$u" ]]; then
            box_line "    └─ $u" "$max_w"
        else
            box_line "    └─ 🤖 用量: —" "$max_w"
        fi
    done
    echo -e "  ${CYAN}├$(print_dash $((max_w + 8)))┤${NC}"
    box_line "直接切换: cswitch <name> --go" "$max_w"
    box_line "$hint_line1" "$max_w"
    box_line "$hint_line2" "$max_w"
    echo -e "  ${CYAN}╰$(print_dash $((max_w + 8)))╯${NC}"

    # 交互选择
    echo ""
    printf '     选择配置 [1-%s] · %bg%b 启动 Claude · 回车取消: ' "$total" "$CYAN" "$NC"
    local choice
    read -r choice
    choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

    # 空输入 → 取消
    [[ -z "$choice" ]] && exit 0

    # g → 使用当前配置直接启动 Claude Code
    if [[ "$choice" == "g" ]]; then
        exec claude
    fi

    # n → 新建配置
    if [[ "$choice" == "n" ]]; then
        create_new_profile
        back_to_menu
    fi

    # o → 打开模型目录
    if [[ "$choice" == "o" ]]; then
        open_profiles_dir
        back_to_menu
    fi

    # u → 升级脚本
    if [[ "$choice" == "u" ]]; then
        cmd_update
        back_to_menu
    fi

    # x → 卸载（确认后退出）
    if [[ "$choice" == "x" ]]; then
        cmd_uninstall
        exit 0
    fi

    # c → 安装/更新 Claude Code
    if [[ "$choice" == "c" ]]; then
        cmd_claude_upgrade
        back_to_menu
    fi

    # 非数字 → 也当成 profile 名直接切换
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        do_switch "$choice" false true
    elif [[ "$choice" -ge 1 && "$choice" -le "$total" ]]; then
        do_switch "${profile_names[$((choice - 1))]}" false true
    else
        echo "  ❌ 无效选择: $choice"
        back_to_menu
    fi
}
