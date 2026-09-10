# SH-TOOLS v2

个人 Bash 工具箱：初始化开发环境、安装 AI Agent、接入项目规则、管理 tmux 会话。

## 开始使用

已有仓库，运行：

```bash
bash sh-tools.sh
```

没有仓库，选择一个下载来源：

**GitHub**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/sh-tools.sh)
```

**Gitee**

```bash
export REPO_RAW_BASE="https://gitee.com/ezios/sh-tools/raw/master"
bash <(curl -fsSL "$REPO_RAW_BASE/sh-tools.sh")
```

远程命令读取 `master` 分支；本地开发中的 v2 改动需发布到该分支后才生效。`REPO_RAW_BASE` 控制后续模块的下载来源。交互执行使用 `bash <(curl …)`，不要用占用标准输入的 `curl … | bash`。

## 选择工具

| 入口 | 用途与详细说明 |
| --- | --- |
| `init-Linux` | [Debian / Ubuntu / WSL 基础开发环境](init-Linux/README.md) |
| `agents` | [Agent 安装、更新、检查及 Claude Code profile](agents/README.md) |
| `skills` | [项目规则模板与 skills 安装](skills/README.md) |
| `add-tmux-help` | [tmux 会话菜单与快捷键帮助](add-tmux-help/README.md) |
| `mihomo` | [Mihomo TUN、Docker 流量代理与 systemd 管理](mihomo/README.md) |

操作结束后留在当前菜单；输入 `0` 返回上一级，总菜单输入 `0` 退出。操作失败会显示错误并回到当前菜单。直接传入子命令时，执行一次后退出并保留退出状态。

新机器先安装基础开发环境，再按需安装 Agent 和项目规则。也可以直接执行：

```bash
bash sh-tools.sh init-Linux all       # 安装基础开发环境
bash sh-tools.sh agents status       # 查看 Agent 状态
bash sh-tools.sh skills agents-template /path/to/project
```

[WireGuard 管理工具](wireguard/README.md) 独立使用，需下载到本机运行，未接入总菜单。

## 版本与验证

`v1.0` 标签保存精简前版本。v2 不保留旧入口兼容性：`install-karpathy-skills` 改用 `skills → karpathy`，`init-Linux devtools` 改用 `agenttools`。tmux 改用独立命令，升级说明见模块文档。

```bash
bash tests/smoke.sh
```
