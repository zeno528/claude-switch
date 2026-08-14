# 自管理：版本、检查更新、升级、卸载

# 安装软链（安装目录 → ~/.local/bin）
ensure_symlink() {
    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/cswitch" "$BIN_DIR/cswitch"
}

cmd_version() {
    say "" "cswitch v$(app_version)"
    say "" "安装目录: $INSTALL_DIR"
    say "" "命令位置: $BIN_DIR/cswitch"
}

cmd_check_update() {
    local local_v remote_v
    local_v="$(app_version)"
    remote_v="$(remote_version)"
    if [[ -z "$remote_v" ]]; then
        say "❌" "无法获取远端版本（$RAW_BASE/VERSION）"
        exit 1
    fi
    if [[ "$local_v" == "$remote_v" ]]; then
        say "✅" "已是最新版本: v$local_v"
    elif version_gt "$remote_v" "$local_v"; then
        say "🔄" "发现新版本: v$local_v → v$remote_v"
        say "" "执行 cswitch update 升级"
    else
        say "ℹ️" "本地版本 v$local_v 高于远端 v$remote_v（开发版或仓库回退）"
    fi
}

cmd_update() {
    local local_v remote_v
    local_v="$(app_version)"
    remote_v="$(remote_version)"
    if [[ -z "$remote_v" ]]; then
        say "❌" "无法获取远端版本（$RAW_BASE/VERSION）"
        exit 1
    fi
    if [[ "$local_v" == "$remote_v" ]]; then
        say "✅" "已是最新版本: v$local_v"
        return
    fi
    if ! version_gt "$remote_v" "$local_v"; then
        say "ℹ️" "本地版本 v$local_v 不旧于远端 v$remote_v，无需升级"
        return
    fi

    say "⬇️" "下载 v$remote_v ..."
    local tmpdir src
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    curl -fsSL -m 60 "$TARBALL_URL" -o "$tmpdir/app.tar.gz" || {
        say "❌" "下载失败: $TARBALL_URL"
        exit 1
    }
    tar -xzf "$tmpdir/app.tar.gz" -C "$tmpdir"
    src="$tmpdir/${REPO#*/}-main"
    [[ -x "$src/cswitch" ]] || {
        say "❌" "下载内容不完整，已中止（未改动现有安装）"
        exit 1
    }

    # 备份旧版 → 替换 → 删备份
    [[ -d "$INSTALL_DIR" ]] && mv "$INSTALL_DIR" "$INSTALL_DIR.bak"
    if ! cp -r "$src" "$INSTALL_DIR"; then
        [[ -d "$INSTALL_DIR.bak" ]] && mv "$INSTALL_DIR.bak" "$INSTALL_DIR"
        say "❌" "替换失败，已恢复旧版"
        exit 1
    fi
    chmod +x "$INSTALL_DIR/cswitch"
    rm -rf "$INSTALL_DIR.bak"
    ensure_symlink

    say "✅" "已升级: v$local_v → v$remote_v"
}

cmd_uninstall() {
    local ans
    read -p "确认卸载 cswitch？(y/N): " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || {
        say "" "已取消"
        return
    }
    say "🗑️" "卸载 cswitch ..."
    rm -f "$BIN_DIR/cswitch"
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        say "" "已删除: $INSTALL_DIR"
    else
        say "" "未发现安装目录: $INSTALL_DIR"
    fi
    say "✅" "卸载完成"
    say "" "（~/.claude 下的 profile / settings 未动，可手动清理）"
}
