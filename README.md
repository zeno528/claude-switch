# claude-switch

一键切换 Claude Code 模型配置（DeepSeek / 智谱 / MiniMax 等），支持交互菜单、用量查询、模板向导和自更新。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/zeno528/claude-switch/main/install.sh | bash
```

若 `~/.local/bin` 不在 PATH，安装器会提示你加入：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## 用法

| 命令 | 说明 |
| --- | --- |
| `claude-switch` | 交互菜单（查看/切换/用量/新建） |
| `claude-switch <name> [--go]` | 切换到 profile，`--go` 切换后启动 Claude |
| `claude-switch new` | 新建模板向导 |
| `claude-switch version` | 显示版本 |
| `claude-switch check-update` | 检查更新 |
| `claude-switch update` | 升级到最新版 |
| `claude-switch uninstall` | 卸载 |

profile 存放在 `~/.claude/model-profiles/`，切换时把 profile 的 `env` 合并进 `~/.claude/settings.json`（带备份回滚），并记录当前配置到 `~/.claude/.current-model-profile`。

## 更新机制

本地 `VERSION` 文件与 GitHub 远端 `VERSION` 比对，`sort -V` 判定版本；有新版时下载 GitHub codeload tarball，备份旧安装目录后替换，不需要目标机器装 git。

## 目录结构

```
claude-switch/
├── claude-switch        # 主入口（参数分发）
├── install.sh           # 一行安装器
├── VERSION              # 版本文件
├── lib/
│   ├── common.sh        # 路径、颜色、宽度/框打印、版本
│   ├── profile.sh       # profile 读取、新建向导
│   ├── switch.sh        # 核心切换逻辑
│   ├── usage.sh         # 三家用量查询
│   ├── menu.sh          # 交互菜单
│   └── selfupdate.sh    # 检查更新 / 升级 / 卸载
└── README.md
```

## 从源码运行

```bash
git clone https://github.com/zeno528/claude-switch.git
cd claude-switch
./claude-switch
```

源码运行同样支持全部子命令，只是 `update` 需要安装目录结构（正常安装后使用）。
