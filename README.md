<p align="center">
  <img alt="版本" src="https://img.shields.io/badge/版本-v0.1.0-orange">
  <img alt="平台" src="https://img.shields.io/badge/平台-Linux%20%7C%20WSL2-blue">
  <img alt="Stars" src="https://img.shields.io/github/stars/zeno528/cswitch?label=Stars">
  <img alt="最后提交" src="https://img.shields.io/github/last-commit/zeno528/cswitch?label=最后提交">
</p>

# cswitch

一键切换 Claude Code 模型配置（DeepSeek / 智谱 / MiniMax 等），支持交互菜单、用量查询、模板向导和自更新。

适用于 **Linux** 和 **WSL2**（Windows Subsystem for Linux 2）。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/zeno528/cswitch/main/install.sh | bash
```

若 `~/.local/bin` 不在 PATH，安装器会提示你加入：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## 用法

| 命令 | 说明 |
| --- | --- |
| `cswitch` | 交互菜单（查看/切换/用量/新建） |
| `cswitch <name> [--go]` | 切换到 profile，`--go` 切换后启动 Claude |
| `cswitch new` | 新建模板向导 |
| `cswitch version` | 显示版本 |
| `cswitch check-update` | 检查更新 |
| `cswitch update` | 升级到最新版 |
| `cswitch uninstall` | 卸载 |

profile 存放在 `~/.claude/model-profiles/`，切换时把 profile 的 `env` 合并进 `~/.claude/settings.json`（带备份回滚），并记录当前配置到 `~/.claude/.current-model-profile`。

## 更新机制

本地 `VERSION` 文件与 GitHub 远端 `VERSION` 比对，`sort -V` 判定版本；有新版时下载 GitHub codeload tarball，备份旧安装目录后替换，不需要目标机器装 git。

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
│   └── selfupdate.sh    # 检查更新 / 升级 / 卸载
└── README.md
```

## 从源码运行

```bash
git clone https://github.com/zeno528/cswitch.git
cd cswitch
./cswitch
```

源码运行同样支持全部子命令，只是 `update` 需要安装目录结构（正常安装后使用）。
