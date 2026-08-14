#!/usr/bin/env bash
# claude-switch 安装器（一行安装）
# 用法: curl -fsSL https://raw.githubusercontent.com/zeno528/claude-switch/main/install.sh | bash
set -euo pipefail

REPO="${CLAUDE_SWITCH_REPO:-zeno528/claude-switch}"
RAW_BASE="${CLAUDE_SWITCH_RAW_BASE:-https://raw.githubusercontent.com/$REPO/main}"
TARBALL_URL="${CLAUDE_SWITCH_TARBALL_URL:-https://codeload.github.com/$REPO/tar.gz/refs/heads/main}"

INSTALL_DIR="${CLAUDE_SWITCH_HOME:-$HOME/.claude-switch}"
BIN_DIR="${HOME}/.local/bin"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "⬇️  下载 claude-switch ..."
curl -fsSL -m 60 "$TARBALL_URL" -o "$tmpdir/app.tar.gz"
tar -xzf "$tmpdir/app.tar.gz" -C "$tmpdir"
src="$tmpdir/${REPO#*/}-main"
[[ -x "$src/claude-switch" ]] || {
    echo "❌ 下载内容不完整，安装中止"
    exit 1
}

mkdir -p "$INSTALL_DIR"
cp -r "$src"/. "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/claude-switch"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/claude-switch" "$BIN_DIR/claude-switch"

version="$(cat "$INSTALL_DIR/VERSION")"
echo "✅ 已安装 claude-switch v$version"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo "⚠️  $BIN_DIR 不在 PATH，先执行（已写入 ~/.bashrc）:"
        echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
        ;;
esac
echo ""
echo "   claude-switch           查看菜单"
echo "   claude-switch update    升级"
echo "   claude-switch uninstall 卸载"
