# SH-TOOLS

常用工具存储仓库。

## 工具列表

| 工具 | 说明 |
|------|------|
| [init-Linux](./init-Linux/init-linux.sh) | Linux/WSL 开发环境初始化脚本 |
| [add-tmux-help](./add-tmux-help/add-tmux-help.sh) | 向 shell 配置添加 tmux 快捷键帮助函数 |
| [proxyctl](./proxyctl/proxyctl.sh) | 代理管理工具，一键管理 Shell/Git/NPM/APT 代理 |
| [install-karpathy-skills](./install-karpathy-skills/install-karpathy-skills.sh) | 下载 `CLAUDE.md` 并创建 `AGENTS.md` 软链接 |
| [sh-tools](./sh-tools.sh) | 总入口脚本，交互选择并调用各工具入口，支持本地/远程双模式 |

## 快速安装

```bash
# sh-tools - 总入口，交互选择工具，本地无仓库时自动走远程模式
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/sh-tools.sh)

# init-Linux - 一键初始化开发环境
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/init-Linux/init-linux.sh)

# add-tmux-help - 添加 tmux 快捷键帮助函数
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/add-tmux-help/add-tmux-help.sh)

# proxyctl - 代理管理工具
curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/proxyctl/proxyctl.sh | sudo tee /usr/local/bin/proxyctl >/dev/null && sudo chmod +x /usr/local/bin/proxyctl

# install-karpathy-skills - 下载 CLAUDE.md 并创建 AGENTS.md 软链接
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/install-karpathy-skills/install-karpathy-skills.sh)
```

## PLAN

- [x] init-Linux
- [x] add-tmux-help
- [x] proxyctl
- [x] install-karpathy-skills
- [x] sh-tools
- [ ] 待续
