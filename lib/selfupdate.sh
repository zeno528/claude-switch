# 自管理：版本、检查更新、升级、卸载

# 安装软链（安装目录 → ~/.local/bin）
ensure_symlink() {
    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/claude-switch" "$BIN_DIR/claude-switch"
}

cmd_version() {
    echo "claude-switch v$(app_version)"
    echo "  安装目录: $INSTALL_DIR"
    echo "  命令位置: $BIN_DIR/claude-switch"
}

cmd_check_update() {
    local local_v remote_v
    local_v="$(app_version)"
    remote_v="$(remote_version)"
    if [[ -z "$remote_v" ]]; then
        echo "❌ 无法获取远端版本（$RAW_BASE/VERSION）"
        exit 1
    fi
    if [[ "$local_v" == "$remote_v" ]]; then
        echo "✅ 已是最新版本: v$local_v"
    elif version_gt "$remote_v" "$local_v"; then
        echo "🔄 发现新版本: v$local_v → v$remote_v"
        echo "   执行 claude-switch update 升级"
    else
        echo "ℹ️  本地版本 v$local_v 高于远端 v$remote_v（开发版或仓库回退）"
    fi
}

cmd_update() {
    local local_v remote_v
    local_v="$(app_version)"
    remote_v="$(remote_version)"
    if [[ -z "$remote_v" ]]; then
        echo "❌ 无法获取远端版本（$RAW_BASE/VERSION）"
        exit 1
    fi
    if [[ "$local_v" == "$remote_v" ]]; then
        echo "✅ 已是最新版本: v$local_v"
        return
    fi
    if ! version_gt "$remote_v" "$local_v"; then
        echo "ℹ️  本地版本 v$local_v 不旧于远端 v$remote_v，无需升级"
        return
    fi

    echo "⬇️  下载 v$remote_v ..."
    local tmpdir src
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    curl -fsSL -m 60 "$TARBALL_URL" -o "$tmpdir/app.tar.gz" || {
        echo "❌ 下载失败: $TARBALL_URL"
        exit 1
    }
    tar -xzf "$tmpdir/app.tar.gz" -C "$tmpdir"
    src="$tmpdir/${REPO#*/}-main"
    [[ -x "$src/claude-switch" ]] || {
        echo "❌ 下载内容不完整，已中止（未改动现有安装）"
        exit 1
    }

    # 备份旧版 → 替换 → 删备份
    [[ -d "$INSTALL_DIR" ]] && mv "$INSTALL_DIR" "$INSTALL_DIR.bak"
    if ! cp -r "$src" "$INSTALL_DIR"; then
        [[ -d "$INSTALL_DIR.bak" ]] && mv "$INSTALL_DIR.bak" "$INSTALL_DIR"
        echo "❌ 替换失败，已恢复旧版"
        exit 1
    fi
    chmod +x "$INSTALL_DIR/claude-switch"
    rm -rf "$INSTALL_DIR.bak"
    ensure_symlink

    echo "✅ 已升级: v$local_v → v$remote_v"
}

cmd_uninstall() {
    local ans
    read -p "确认卸载 claude-switch？(y/N): " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || {
        echo "已取消"
        return
    }
    echo "🗑️  卸载 claude-switch ..."
    rm -f "$BIN_DIR/claude-switch"
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "  已删除: $INSTALL_DIR"
    else
        echo "  未发现安装目录: $INSTALL_DIR"
    fi
    echo "✅ 卸载完成"
    echo "  （~/.claude 下的 profile / settings 未动，可手动清理）"
}
