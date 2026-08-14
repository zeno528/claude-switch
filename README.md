<p align="center" style="margin-bottom:0">
  <img src="assets/icon.png" width="120" style="margin-bottom:-24px" alt="cswitch">
</p>

<h1 align="center" style="color:#3faec2;font-weight:bold;margin-top:0">cswitch</h1>

<p align="center">
  <img alt="Version" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fzeno528%2Fcswitch%2Fmain%2FVERSION">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20WSL2-blue">
  <img alt="Shell" src="https://img.shields.io/badge/Shell-Bash-89e051">
  <img alt="License" src="https://img.shields.io/github/license/zeno528/cswitch">
</p>

**cswitch** 是一个命令行脚本，一键切换 Claude Code 模型配置（DeepSeek / 智谱 / MiniMax 等），支持交互菜单、用量查询、配置向导、**Claude Code 安装与日常更新**，以及脚本自更新。

适用于 **Linux**、**macOS** 和 **WSL2**（Windows Subsystem for Linux 2），要求 `bash 3.2+`（macOS 自带）、`python3`、`curl`。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/zeno528/cswitch/main/install.sh | bash
```

若 `~/.local/bin` 不在 PATH，安装器会提示你加入：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

macOS 默认 shell 是 zsh 的话，改用：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

<p align="center">
  <img src="assets/menu.png" alt="cswitch 菜单界面">
</p>

## 用法

| 命令 | 说明 |
| --- | --- |
| `cswitch` | 交互菜单（查看/切换/用量/新建） |
| `cswitch <name> --go` | 切换到 profile（不带 `--go` 只切换），加 `--go` 切换后启动 Claude |
| `cswitch new` | 新建配置向导 |
| `cswitch version` | 显示版本 |
| `cswitch check-update` | 检查更新 |
| `cswitch update` | 升级到最新版 |
| `cswitch claude` | 安装/更新 Claude Code（自动检测安装方式：官方安装器 / Homebrew；`--info` 查看状态） |
| `cswitch uninstall` | 卸载 |

profile 存放在 `~/.claude/model-profiles/`，切换时把 profile 的 `env` 合并进 `~/.claude/settings.json`（带备份回滚），并记录当前配置到 `~/.claude/.current-model-profile`。

**修改配置**：菜单按 `o` 打开配置目录，或直接编辑 `~/.claude/model-profiles/<名称>.json`（如修改 API 地址、Key、模型 ID），保存后下次切换即生效。

## 更新机制

本地 `VERSION` 文件与 GitHub 远端 `VERSION` 比对，Python 逐段比较版本号；有新版时下载 GitHub codeload tarball，备份旧安装目录后替换，不需要目标机器装 git。

Claude Code 自身的安装与更新走 `cswitch claude`：自动检测当前安装方式（官方安装器 / Homebrew），原生安装用 `claude update`，Homebrew 用 `brew upgrade` 对应 cask。npm 安装已被官方废弃，检测到时会提示迁移到官方安装器。

## 目录结构

```
cswitch/
├── cswitch        # 主入口（参数分发）
├── install.sh           # 一行安装器
├── VERSION              # 版本文件
├── lib/
│   ├── common.sh        # 路径、颜色、宽度/框打印、版本
│   ├── profile.sh       # profile 读取、新建向导
│   ├── switch.sh        # 核心切换逻辑
│   ├── usage.sh         # 三家用量查询
│   ├── menu.sh          # 交互菜单
│   ├── selfupdate.sh    # 脚本检查更新 / 升级 / 卸载
│   └── claude-upgrade.sh # Claude Code 安装 / 升级（按安装方式分派）
└── README.md
```

## 从源码运行

```bash
git clone https://github.com/zeno528/cswitch.git
cd cswitch
./cswitch
```

源码运行同样支持全部子命令，只是 `update` 需要安装目录结构（正常安装后使用）。

## 反馈与建议

欢迎通过 [GitHub Issues](https://github.com/zeno528/cswitch/issues) 提交 bug 反馈、功能建议或使用疑问。

提 bug 时请附上：

- 系统环境（Linux / macOS / WSL2）
- `cswitch version` 与 `claude --version` 的输出
- 复现步骤和完整报错信息

## License

[MIT](LICENSE)
