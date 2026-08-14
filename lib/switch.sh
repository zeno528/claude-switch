# shellcheck shell=bash
# 核心切换：合并 env 到 settings.json（带备份回滚）、记录状态、成功提示

# do_switch <profile_name> [go_mode] [interactive]
do_switch() {
    local profile_name="$1" go_mode="${2:-false}" interactive="${3:-false}"
    local profile_file="" pname

    # 大小写不敏感查找 profile（统一用文件真实名）
    for f in "$PROFILES_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        pname=$(basename "$f" .json)
        if [[ "${pname,,}" == "${profile_name,,}" ]]; then
            profile_file="$f"
            profile_name="$pname"
            break
        fi
    done

    if [[ -z "$profile_file" ]]; then
        say "❌" "找不到 profile: $profile_name"
        say "" "可用 profile:"
        for f in "$PROFILES_DIR"/*.json; do
            [[ -f "$f" ]] || continue
            avail=$(basename "$f" .json)
            pdesc=$(profile_model "$f")
            [[ -z "$pdesc" ]] && pdesc="$avail"
            say "" "- $avail — $pdesc"
        done
        if $interactive; then back_to_menu; fi
        exit 1
    fi

    # 检查 settings.json 是否存在
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        say "❌" "找不到 settings.json: $SETTINGS_FILE"
        exit 1
    fi

    # 备份
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"

    # 用 python3 合并 env 到 settings.json
    if ! python3 << PYEOF 2>/dev/null; then
import json, os, glob

profile_file = '$profile_file'
settings_file = '$SETTINGS_FILE'
profiles_dir = '$PROFILES_DIR'

with open(profile_file) as f:
    profile = json.load(f)

with open(settings_file) as f:
    settings = json.load(f)

if 'env' not in settings:
    settings['env'] = {}

# 从所有 profile 文件自动收集 env 键
all_model_keys = set()
for f in glob.glob(os.path.join(profiles_dir, '*.json')):
    with open(f) as fh:
        p = json.load(fh)
    all_model_keys.update(p.get('env', {}).keys())

# 清除所有模型相关键
for k in all_model_keys:
    settings['env'].pop(k, None)

# 写入新 profile 的 env
for k, v in profile['env'].items():
    settings['env'][k] = v

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print(json.dumps(settings['env'], indent=2, ensure_ascii=False))
PYEOF
        say "❌" "更新 settings.json 失败，已恢复备份"
        mv "${SETTINGS_FILE}.bak" "$SETTINGS_FILE"
        exit 1
    fi

    # 记录当前 profile
    echo "$profile_name" > "$STATE_FILE"

    # 获取 profile 生效的模型 id
    local pdesc
    pdesc=$(profile_model "$profile_file")
    [[ -z "$pdesc" ]] && pdesc="$profile_name"

    # 切换成功提示（圆角框）
    local success_line warn_line max_w ww
    success_line="✅ 已切换到: ${pdesc} (${profile_name})"
    warn_line="💡 请重启 Claude Code 使新配置生效"

    # 计算框宽
    max_w=$(str_width "$success_line")
    ww=$(str_width "$warn_line")
    [[ $ww -gt $max_w ]] && max_w=$ww
    (( max_w < 30 )) && max_w=30

    echo ""
    echo -e "  ${CYAN}╭$(print_dash $((max_w + 6)))╮${NC}"
    box_line "$success_line" "$max_w"
    echo -e "  ${CYAN}├$(print_dash $((max_w + 6)))┤${NC}"
    box_line "$warn_line" "$max_w"
    echo -e "  ${CYAN}╰$(print_dash $((max_w + 6)))╯${NC}"
    echo ""

    if $go_mode; then
        say "🚀" "启动 Claude Code..."
        echo ""
        claude
    fi

    # 交互模式：切换完成后回到菜单
    if $interactive; then
        back_to_menu
    fi
}
