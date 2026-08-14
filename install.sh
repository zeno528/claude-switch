#!/usr/bin/env bash
# cswitch 安装器（一行安装）
# 用法: curl -fsSL https://raw.githubusercontent.com/zeno528/cswitch/main/install.sh | bash
set -euo pipefail

REPO="${CSWITCH_REPO:-zeno528/cswitch}"
RAW_BASE="${CSWITCH_RAW_BASE:-https://raw.githubusercontent.com/$REPO/main}"
TARBALL_URL="${CSWITCH_TARBALL_URL:-https://codeload.github.com/$REPO/tar.gz/refs/heads/main}"

INSTALL_DIR="${CSWITCH_HOME:-$HOME/.cswitch}"
BIN_DIR="${HOME}/.local/bin"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "⬇️  下载 cswitch ..."
curl -fsSL -m 60 "$TARBALL_URL" -o "$tmpdir/app.tar.gz"
tar -xzf "$tmpdir/app.tar.gz" -C "$tmpdir"
src="$tmpdir/${REPO#*/}-main"
[[ -x "$src/cswitch" ]] || {
    echo "❌ 下载内容不完整，安装中止"
    exit 1
}

mkdir -p "$INSTALL_DIR"
cp -r "$src"/. "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/cswitch"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/cswitch" "$BIN_DIR/cswitch"

version="$(cat "$INSTALL_DIR/VERSION")"
echo "✅ 已安装 cswitch v$version"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo "⚠️  $BIN_DIR 不在 PATH，先执行（已写入 ~/.bashrc）:"
        echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
        ;;
esac
echo ""
echo "   cswitch           查看菜单"
echo "   cswitch update    升级"
echo "   cswitch uninstall 卸载"
