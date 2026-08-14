# profile：读取、新建配置

# profile 描述统一显示切换后实际生效的模型 id：
# ANTHROPIC_MODEL 优先，为空则用 ANTHROPIC_DEFAULT_SONNET_MODEL，再退回 name
profile_model() {
    python3 -c "
import json
try:
    d = json.load(open('$1'))
    e = d.get('env', {})
    print(e.get('ANTHROPIC_MODEL') or e.get('ANTHROPIC_DEFAULT_SONNET_MODEL') or d.get('name', ''))
except Exception:
    print('')
" 2>/dev/null
}

# 读取单个 profile 的 baseURL+token（用于用量查询），stdout 输出 "url|token"
read_profile_url_token() {
    local pfile="$1"
    [[ -f "$pfile" ]] || { echo "|"; return; }
    python3 -c "
import json
try:
    with open('$pfile') as f:
        d = json.load(f)
    env = d.get('env', {})
    print(env.get('ANTHROPIC_BASE_URL', '') + '|' + env.get('ANTHROPIC_AUTH_TOKEN', ''))
except Exception:
    print('|')
" 2>/dev/null
}

# 新建配置向导
create_new_profile() {
    echo ""

    # 名称：输错当场提示并重试，不浪费后面两步输入；空输入取消
    local profile_file=""
    while true; do
        read -p "     请输入配置名称: " name

        # 空输入取消
        if [[ -z "$name" ]]; then
            say "⚪" "已取消"
            return
        fi

        # 校验：只能用字母、数字、下划线、连字符
        if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            say "❌" "${RED}名称只能包含字母、数字、下划线、连字符，请重新输入${NC}"
            continue
        fi

        profile_file="$PROFILES_DIR/${name}.json"

        # 校验：文件已存在
        if [[ -f "$profile_file" ]]; then
            say "❌" "${RED}配置已存在: $name，请换个名称${NC}"
            continue
        fi
        break
    done

    read -p "     请输入调用地址: " api_url
    read -p "     请输入 API Key: " api_token
    # 模型 id：回填三个 DEFAULT 字段；留空则跳过，之后手动编辑
    read -p "     请输入模型 ID（回车跳过）: " model_id
    # 自动压缩窗口：回车默认 1000000（约等于关闭自动压缩）
    read -p "     自动压缩窗口 Token 数（回车默认 1000000）: " compact_window
    compact_window="${compact_window:-1000000}"

    # 生成 JSON
    cat > "$profile_file" << 'JSONEOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "",
    "ANTHROPIC_AUTH_TOKEN": "",
    "ANTHROPIC_MODEL": "",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "",
    "CLAUDE_CODE_SUBAGENT_MODEL": "",
    "CLAUDE_CODE_EFFORT_LEVEL": ""
  }
}
JSONEOF

    # 用 python3 设置字段（name 已无用，菜单显示模型 id）
    python3 -c "
import json
with open('$profile_file') as f:
    d = json.load(f)
d['env']['ANTHROPIC_BASE_URL'] = '$api_url'
d['env']['ANTHROPIC_AUTH_TOKEN'] = '$api_token'
if '$model_id':
    for k in ('ANTHROPIC_DEFAULT_OPUS_MODEL',
              'ANTHROPIC_DEFAULT_SONNET_MODEL',
              'ANTHROPIC_DEFAULT_HAIKU_MODEL'):
        d['env'][k] = '$model_id'
d['env']['CLAUDE_CODE_AUTO_COMPACT_WINDOW'] = '$compact_window'
with open('$profile_file', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
"

    say "✅" "${GREEN}已创建: $profile_file${NC}"
    open_profiles_dir
}
