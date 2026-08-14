# shellcheck shell=bash
# 用量查询：DeepSeek / 智谱 / MiniMax

# slug → provider 键名映射（bash 3.2 兼容：固定列表 + case，不用关联数组）
SLUGS="deepseek zhipu minimax"
slug_provider() {
    case "$1" in
        deepseek) echo ds ;;
        zhipu) echo glm ;;
        minimax) echo mm ;;
    esac
}

# 调用单个 provider 的用量 API，结果写入 $4（"key|display" 格式）
# 用法: fetch_provider_usage <key> <base_url> <token> <out_file>
# key ∈ {ds, glm, mm}
fetch_provider_usage() {
    local key="$1" base_url="$2" token="$3" out_file="$4"

    [[ -n "$base_url" && -n "$token" ]] || {
        printf '%s|\n' "$key" > "$out_file"
        return
    }

    case "$key" in
        ds)
            if ! echo "$base_url" | grep -qE 'api\.deepseek\.com|deepseek\.com'; then
                printf '%s|\n' "$key" > "$out_file"
                return
            fi
            local resp result st cur tot color
            resp=$(curl -s -m 3 -H "Authorization: Bearer $token" \
                "https://api.deepseek.com/user/balance" 2>/dev/null) || resp=""
            result=$(echo "$resp" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    is_available = data.get('is_available', False)
    balance_infos = data.get('balance_infos', [])
    if balance_infos:
        info = balance_infos[0]
        currency = info.get('currency', '')
        total = info.get('total_balance', '0')
        status = '✓' if is_available else '✗'
        print(f'{status}|{currency}|{total}')
    else:
        print('?||0')
except Exception:
    print('?||0')
" 2>/dev/null)
            if [[ "$result" == *"|"* ]]; then
                st=$(echo "$result" | cut -d'|' -f1)
                cur=$(echo "$result" | cut -d'|' -f2)
                tot=$(echo "$result" | cut -d'|' -f3)
                if [[ "$tot" != "0" && -n "$tot" ]]; then
                    [[ "$st" == "✓" ]] && color=$'\033[0;32m' || color=$'\033[0;33m'
                    printf "%s|%s🐋 DS: %s %s\033[0m\n" "$key" "$color" "$tot" "$cur" > "$out_file"
                else
                    printf "%s|\033[0;33m🐋 DS: N/A\033[0m\n" "$key" > "$out_file"
                fi
            else
                printf "%s|\033[0;33m🐋 DS: N/A\033[0m\n" "$key" > "$out_file"
            fi
            ;;
        glm)
            if ! echo "$base_url" | grep -qE 'open\.bigmodel\.cn|dev\.bigmodel\.cn|api\.z\.ai'; then
                printf '%s|\n' "$key" > "$out_file"
                return
            fi
            local base_domain quota_url resp result cc
            base_domain=$(echo "$base_url" | sed -E 's|(https?://[^/]+).*|\1|')
            quota_url="${base_domain}/api/monitor/usage/quota/limit"
            resp=$(curl -s -m 3 -H "Authorization: $token" \
                -H "Content-Type: application/json" "$quota_url" 2>/dev/null) || resp=""
            result=$(echo "$resp" | python3 -c "
import json, sys, time
try:
    data = json.load(sys.stdin)
    if 'data' in data and 'limits' in data['data']:
        # 智谱返回多个 TOKENS_LIMIT（5h、周、月等），逐条显示
        # unit 周期编码（经验，无官方文档）：3=小时, 5=月, 6=周
        def period_label(unit, number):
            if unit == 3: return f'{number}h'
            if unit == 6: return '周'
            if unit == 5: return f'{number}月'
            return f'{number}?u{unit}'

        token_limits = [l for l in data['data']['limits'] if l.get('type') == 'TOKENS_LIMIT']
        if token_limits:
            # 整体颜色取消耗最高的（最紧急）
            max_pct = max(l.get('percentage', 0) for l in token_limits)
            color_code = 32 if max_pct < 50 else (33 if max_pct < 80 else 31)

            parts = []
            for tl in token_limits:
                pct = tl.get('percentage', 0)
                cd = ''
                nr = tl.get('nextResetTime', 0)
                if nr:
                    remaining = nr / 1000 - time.time()
                    if remaining > 0:
                        d = int(remaining // 86400)
                        h = int((remaining % 86400) // 3600)
                        m2 = int((remaining % 3600) // 60)
                        if d > 0:
                            cd = f' ({d}d{h}h)' if h else f' ({d}d)'
                        elif h > 0:
                            cd = f' ({h}h{m2}m)' if m2 else f' ({h}h)'
                        else:
                            cd = f' ({m2}m)'
                label = period_label(tl.get('unit', 0), tl.get('number', 0))
                parts.append(f'{label} {pct}%{cd}')

            display = ' / '.join(parts)
            print(f'{color_code}|{display}')
            sys.exit(0)
    print('|0|')
except Exception:
    print('|0|')
" 2>/dev/null)
            if [[ "$result" == *"|"* ]]; then
                cc=$(echo "$result" | cut -d'|' -f1)
                display=$(echo "$result" | cut -d'|' -f2-)
                if [[ -n "$display" ]]; then
                    printf "%s|\033[0;%sm🧠 GLM: %s\033[0m\n" "$key" "$cc" "$display" > "$out_file"
                else
                    printf "%s|\033[0;33m🧠 GLM: N/A\033[0m\n" "$key" > "$out_file"
                fi
            else
                printf "%s|\033[0;33m🧠 GLM: N/A\033[0m\n" "$key" > "$out_file"
            fi
            ;;
        mm)
            if ! echo "$base_url" | grep -qE 'minimaxi\.com|minimax\.io'; then
                printf '%s|\n' "$key" > "$out_file"
                return
            fi
            local quota_url resp result cc
            if echo "$base_url" | grep -qE 'minimax\.io'; then
                quota_url="https://api.minimax.io/v1/token_plan/remains"
            else
                quota_url="https://api.minimaxi.com/v1/token_plan/remains"
            fi
            resp=$(curl -s -m 3 -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" "$quota_url" 2>/dev/null) || resp=""
            result=$(echo "$resp" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('base_resp', {}).get('status_code') != 0:
        print(''); sys.exit(0)
    remains = data.get('model_remains', [])
    if not remains: print(''); sys.exit(0)
    m = next((r for r in remains if r.get('model_name')=='general' and r.get('current_interval_status')==1), None)
    if not m: m = next((r for r in remains if r.get('current_interval_status')==1), None)
    if not m: m = remains[0]

    # MiniMax 每个 model 有 5h interval + weekly 两套额度，逐条显示
    def format_cd(ms):
        if not ms or ms <= 0: return ''
        d = int(ms // 86400000)
        h = int((ms % 86400000) // 3600000)
        m2 = int((ms % 3600000) // 60000)
        if d > 0: return f' ({d}d{h}h)' if h else f' ({d}d)'
        if h > 0: return f' ({h}h{m2}m)' if m2 else f' ({h}h)'
        return f' ({m2}m)'

    parts = []
    consumed_list = []
    # 5h interval（current_interval_*）
    if m.get('current_interval_status') == 1:
        rp = m.get('current_interval_remaining_percent')
        if rp is None: rp = m.get('usagePercent')
        if rp is None: rp = m.get('usage_percent')
        if rp is not None:
            pct = max(0.0, min(100.0, round(100 - float(rp), 1)))
            consumed_list.append(pct)
            parts.append(f'5h {pct:g}%{format_cd(m.get(\"remains_time\", 0))}')
    # weekly（current_weekly_*）
    if m.get('current_weekly_status') == 1:
        rp = m.get('current_weekly_remaining_percent')
        if rp is not None:
            pct = max(0.0, min(100.0, round(100 - float(rp), 1)))
            consumed_list.append(pct)
            parts.append(f'周 {pct:g}%{format_cd(m.get(\"weekly_remains_time\", 0))}')

    if not parts:
        print(''); sys.exit(0)
    # 整体颜色取最高消耗
    max_pct = max(consumed_list)
    color_code = 32 if max_pct < 50 else (33 if max_pct < 80 else 31)
    display = ' / '.join(parts)
    print(f'{color_code}|{display}')
except Exception:
    print('')
" 2>/dev/null)
            if [[ "$result" == *"|"* ]]; then
                cc=$(echo "$result" | cut -d'|' -f1)
                display=$(echo "$result" | cut -d'|' -f2-)
                if [[ -n "$display" ]]; then
                    printf "%s|\033[0;%sm🚀 MiniMax: %s\033[0m\n" "$key" "$cc" "$display" > "$out_file"
                else
                    printf '%s|\n' "$key" > "$out_file"
                fi
            else
                printf '%s|\n' "$key" > "$out_file"
            fi
            ;;
    esac
}

# 并行查询全部 provider 用量，输出 slug → display 的关联数组到 stdout（key|display 每行）
# 输出 key|display 行，调用方按行承接
query_all_usage() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    # 为每个匹配的 profile 启动一个后台 curl
    for slug in $SLUGS; do
        prov=$(slug_provider "$slug")
        [[ -f "$PROFILES_DIR/$slug.json" ]] || continue
        ut=$(read_profile_url_token "$PROFILES_DIR/$slug.json")
        base_url="${ut%%|*}"
        token="${ut##*|}"
        fetch_provider_usage "$prov" "$base_url" "$token" "$tmpdir/$prov" &
    done

    wait   # 最长 3s（每个 curl -m 3）

    # 输出 key|display 行（无数据的 provider 跳过）
    for prov in ds glm mm; do
        f="$tmpdir/$prov"
        [[ -f "$f" ]] || continue
        line=$(cat "$f")
        [[ -z "${line#*|}" ]] && continue
        echo "$line"
    done
}
