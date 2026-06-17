# SH-TOOLS

常用工具存储仓库。

## 工具列表

| 工具 | 说明 |
|------|------|
| [init-Linux](./init-Linux/init-linux.sh) | Debian 系 Linux 开发环境初始化脚本，包含 WSL 可选增强 |
| [add-tmux-help](./add-tmux-help/add-tmux-help.sh) | 向 shell 配置添加 tmux 快捷键帮助函数 |
| [proxyctl](./proxyctl/proxyctl.sh) | 代理管理工具，一键管理 Shell/Git/NPM/APT 代理 |
| [install-karpathy-skills](./install-karpathy-skills/install-karpathy-skills.sh) | 兼容旧入口，实际委托给 `skills/karpathy` |
| [agents](./agents/agents.sh) | AI agent 工具安装入口，支持 Codex、Claude Code、OpenCode、Hermes、Pi Agent |
| [skills](./skills/skills.sh) | skills 安装入口，当前包含 `karpathy` 和 `mattpocock/skills` |
| [sh-tools](./sh-tools.sh) | 总入口脚本，交互选择并调用各工具入口，支持本地/远程双模式 |

## 快速安装

```bash
# sh-tools - 总入口，交互选择工具，本地无仓库时自动走远程模式
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/sh-tools.sh)

# init-Linux - Debian 系 Linux 开发环境初始化
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/init-Linux/init-linux.sh)

# add-tmux-help - 添加 tmux 快捷键帮助函数
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/add-tmux-help/add-tmux-help.sh)

# proxyctl - 代理管理工具
curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/proxyctl/proxyctl.sh | sudo tee /usr/local/bin/proxyctl >/dev/null && sudo chmod +x /usr/local/bin/proxyctl

# agents - AI agent 工具安装入口，内部再选择具体 agent 和安装方式
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/agents/agents.sh)

# skills - skills 安装入口，内部再选择具体 provider
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/skills/skills.sh)

# skills/karpathy - 下载 CLAUDE.md 并创建 AGENTS.md 软链接
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/skills/providers/karpathy.sh)

# 兼容旧入口，等价于 skills/karpathy
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/install-karpathy-skills/install-karpathy-skills.sh)
```

## PLAN

- [x] init-Linux
- [x] add-tmux-help
- [x] proxyctl
- [x] install-karpathy-skills
- [x] agents
- [x] skills
- [x] sh-tools
- [ ] 待续
