# init-Linux

Debian 系 Linux 开发环境初始化脚本，支持交互式菜单和命令行参数两种使用方式，WSL 相关能力作为可选增强提供。

## 功能

- 检测系统环境与安装状态（Debian / Ubuntu / Linux Mint / Pop!_OS / Kali / WSL 等 apt 系环境）
- 配置软件源（清华镜像等）
- 安装基础依赖（curl、wget、git 等）
- 安装常用开发工具（tmux、fzf、ripgrep、jq、tree、zip）
- 初始化 Git 全局配置（用户名、邮箱、默认分支、编辑器）
- 下载类步骤自动复用当前代理环境，并在失败时给出代理提示
- 安装 zsh + Oh My Zsh + Powerlevel10k
- 安装 nvm + Node.js LTS
- 配置 Node 工具链（corepack、pnpm）
- 安装 Python 开发工具（python3、pip3、venv）
- 初始化 SSH key（ed25519）
- 查看 WSL 状态与建议
- 安装 uv
- 修复 nvm / uv 环境变量

脚本设计为幂等，可重复执行，不会破坏已有配置。

## 使用方式

### 本地执行

```bash
bash init-linux.sh
```

无参数进入交互式菜单，也可传入子命令直接执行特定步骤：

```bash
bash init-linux.sh check    # 查看系统与工具状态摘要
bash init-linux.sh all      # 一键安装全部
bash init-linux.sh devtools # 安装常用开发工具
bash init-linux.sh gitcfg   # 初始化 Git 全局配置
bash init-linux.sh zsh      # 仅安装 zsh
bash init-linux.sh nvm      # 仅安装 nvm
bash init-linux.sh node     # 仅安装 Node.js LTS
bash init-linux.sh nodetools # 配置 corepack / pnpm
bash init-linux.sh pytools  # 安装 Python 开发工具
bash init-linux.sh ssh-init # 初始化 SSH key
bash init-linux.sh wsl      # 查看 WSL 状态与建议
```

### 一键远程执行

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/init-Linux/init-linux.sh)
```

> ⚠️ 不要使用 `curl ... | bash` 方式，管道会占用 stdin 导致交互式菜单无法输入。

## 支持范围

主要支持 `apt/dpkg` 体系的 Debian 系发行版，包括但不限于：

- Ubuntu
- Debian
- Linux Mint
- Pop!_OS
- Kali
- 其他兼容 `apt` 的 Debian 系发行版

WSL 不是单独产品线，而是上述 Debian 系环境上的可选增强场景。

其他没有 `apt` 的系统不在主要支持范围内。

## 后续计划

功能扩展路线见：[ROADMAP.md](./ROADMAP.md)

## check 会检查什么

`check` 会输出当前机器的状态摘要，帮助判断下一步该执行哪个子命令。当前覆盖：

- 系统环境：`apt`、WSL、当前 shell、当前用户、代理环境
- 核心工具：`curl`、`wget`、`git`
- 常用工具状态：`tmux`、`fzf`、`rg`、`jq`、`tree`、`zip`
- Shell 栈：`zsh`、Oh My Zsh、Powerlevel10k、主题配置
- Node 栈：`nvm`、`node`、`npm`、`corepack`、`pnpm`
- Python / uv：`python3`、`pip3`、`uv`
- Shell rc 配置：`~/.bashrc` / `~/.zshrc` 中的 `nvm` 环境变量与 `uv` PATH

## devtools 会安装什么

`devtools` 会检查并安装以下常用开发工具：

- `tmux`
- `fzf`
- `ripgrep`
- `jq`
- `tree`
- `zip`

如果这些包都已经安装，命令会直接跳过。

## gitcfg 会配置什么

`gitcfg` 会交互式检查并设置以下 Git 全局配置：

- `user.name`
- `user.email`
- `init.defaultBranch`
- `core.editor`

如果某项已经存在，脚本会先显示当前值，再询问是否更新。

## nodetools 会做什么

`nodetools` 会在 Node.js 已可用的前提下执行：

- `corepack enable`
- 可选执行 `corepack prepare pnpm@latest --activate`

执行结束后会输出 `node`、`npm`、`corepack`、`pnpm` 的当前状态。

## pytools 会做什么

`pytools` 会检查并安装以下 Python 开发工具：

- `python3`
- `python3-pip`
- `python3-venv`

执行结束后会输出 `python3`、`pip3`，并检查 `python3 -m venv` 是否可用。

## ssh-init 会做什么

`ssh-init` 会完成以下工作：

- 检查 `ssh-keygen` 是否可用
- 创建 `~/.ssh` 并修正目录权限
- 若不存在 key，则生成 `ed25519` key
- 修正私钥、公钥权限
- 输出公钥路径、下一步提示和公钥内容

如果全局 Git 邮箱已配置，脚本会把它作为 SSH key comment。

## wsl 会做什么

`wsl` 会输出：

- 当前是否运行在 WSL
- `/etc/wsl.conf` 是否存在
- 是否检测到 `metadata = true`
- 针对 WSL 开发环境的后续建议

## 下载步骤的代理行为

以下步骤现在会统一复用当前 shell 中的代理环境变量，并在下载失败时给出明确提示：

- `mirror`
- `ohmyzsh`
- `nvm`
- `uv`

如果当前 shell 已设置 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`，脚本会沿用这些配置下载。
