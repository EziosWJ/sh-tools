# Ubuntu / WSL 初始化脚本

`init-ubuntu.sh` 用于 Ubuntu / Debian / WSL Ubuntu 的常用开发环境初始化。脚本支持交互式菜单和命令行参数两种使用方式，重点目标是可重复执行、尽量不破坏用户已有配置，并且不会自动切换默认 shell。

## 支持范围

- Ubuntu
- Debian
- WSL Ubuntu

如果系统没有 `apt`，脚本会提示当前环境不在主要支持范围内，安装类操作会中止。

## 快速开始

直接执行脚本会进入交互式菜单：

```bash
bash init-ubuntu.sh
```

如果你已经给脚本加了可执行权限，也可以直接运行：

```bash
./init-ubuntu.sh
```

先给执行权限：

```bash
chmod +x init-ubuntu.sh
```

## 交互式使用

进入菜单后，可以按编号选择功能：

```text
1) 检测系统环境
2) 配置软件源
3) 检查并安装基础依赖
4) 安装 zsh
5) 安装 Oh My Zsh
6) 安装 Powerlevel10k
7) 安装 nvm
8) 安装 Node.js LTS
9) 安装 uv
10) 修复 nvm / uv 环境变量
11) 一键安装全部
0) 退出
```

## 命令行参数

脚本支持以下参数：

```bash
bash init-ubuntu.sh all
bash init-ubuntu.sh check
bash init-ubuntu.sh mirror
bash init-ubuntu.sh deps
bash init-ubuntu.sh zsh
bash init-ubuntu.sh ohmyzsh
bash init-ubuntu.sh p10k
bash init-ubuntu.sh nvm
bash init-ubuntu.sh node
bash init-ubuntu.sh uv
bash init-ubuntu.sh env
```

含义如下：

- `all`：按固定顺序一键执行全部流程
- `check`：检测系统环境
- `mirror`：启动 `linuxmirrors.cn` 的交互式镜像源配置脚本
- `deps`：检查并安装基础依赖
- `zsh`：安装 `zsh`
- `ohmyzsh`：安装 Oh My Zsh
- `p10k`：安装 Powerlevel10k 主题
- `nvm`：安装 `nvm`
- `node`：安装 Node.js LTS，并设置为默认版本
- `uv`：安装 `uv`
- `env`：修复已存在的 `~/.bashrc` / `~/.zshrc` 中的 `nvm / uv` 环境变量

无参数执行时，默认进入交互式菜单。

## 一键安装全部

`all` 的执行顺序固定为：

1. 检测系统环境
2. 配置镜像源
3. `apt update`
4. 检查并安装基础依赖
5. 安装 `zsh`
6. 安装 Oh My Zsh
7. 安装 Powerlevel10k
8. 安装 `nvm`
9. 安装 Node.js LTS，并设置为 default
10. 安装 `uv`
11. 修复已存在 shell 配置文件中的环境变量
12. 输出结束提示

## 使用说明

### 1. 配置软件源

`mirror` 会启动第三方交互式脚本：

```bash
bash init-ubuntu.sh mirror
```

脚本不会用 `expect` 自动输入选项，也不会强行代填。一般建议在镜像源工具里选择：

- 清华大学源
- HTTP
- 不更新软件包

### 2. 安装基础依赖

`deps` 会检查并安装这些基础依赖：

- `curl`
- `wget`
- `git`
- `ca-certificates`
- `unzip`
- `tar`
- `build-essential`

如果缺少依赖，脚本会先提示，再询问是否安装。

### 3. 安装 zsh

`zsh` 安装完成后，脚本不会自动执行 `chsh`。如果你想手动切换默认 shell，可以执行：

```bash
chsh -s "$(command -v zsh)"
```

### 4. 安装 Oh My Zsh

脚本会检查 `~/.oh-my-zsh` 是否已存在，存在则跳过，避免重复安装。

在 WSL + Clash 这类代理环境中，如果检测到 `HTTP_PROXY`、`HTTPS_PROXY`、`http_proxy` 或 `https_proxy`，脚本会在 GitHub clone 时显式传递 Git 代理配置，减少卡在 `Cloning Oh My Zsh...` 的情况。

如果 `~/.oh-my-zsh` 目录存在但缺少 `oh-my-zsh.sh`，脚本会认为上次安装可能中断，并提示你手动检查该目录。脚本不会自动删除用户目录。

### 5. 安装 Powerlevel10k

主题安装路径固定为：

```bash
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

脚本只会在 `~/.zshrc` 已存在时修改主题配置，不会自动创建 `~/.zshrc`。

Powerlevel10k 从 GitHub clone 时也会复用上述代理处理逻辑。

### 6. 安装 nvm 和 Node.js LTS

`nvm` 安装完成后，脚本会尝试修复已存在的 `~/.bashrc` / `~/.zshrc`，并在当前进程中加载 `nvm`。

`node` 会先检查 `nvm` 是否可用，不可用时会提示你先安装 `nvm`。

### 7. 安装 uv

`uv` 安装完成后，脚本会补充：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

并尝试修复已存在的 `~/.bashrc` / `~/.zshrc`。

### 8. 修复环境变量

`env` 会先检测目标用户目录中是否已经安装了 `nvm` / `uv`，再修复已存在的 shell 配置文件：

- 如果检测到 `$HOME/.nvm/nvm.sh`，会确保已有的 `~/.bashrc` / `~/.zshrc` 包含 `nvm` 配置
- 如果检测到 `$HOME/.local/bin/uv` 或当前环境可执行 `uv`，会确保已有的 `~/.bashrc` / `~/.zshrc` 包含 uv 的 PATH 配置
- 如果其中某个配置文件不存在，只提示并跳过，不会自动创建

脚本只修改已经存在的 `~/.bashrc` / `~/.zshrc`，不会自动创建 `~/.zshrc`，也不会自动切换默认 shell。修复完成后，脚本只会尝试 source 当前 shell 对应的配置文件。

## 幂等性

脚本设计目标之一就是可重复执行。重复运行时，会尽量跳过以下内容：

- 已存在的组件
- 已存在的 Powerlevel10k 仓库
- 已存在的 Oh My Zsh
- 已存在的 `nvm` 配置块
- 已存在的 `uv` PATH 配置
- 已存在的主题配置

这意味着你可以在重启终端后再次执行脚本，补齐遗漏步骤，而不会反复污染配置文件。

## 结束提示

如果你安装了 `zsh`，但还没有切换默认 shell，脚本会提示你手动执行：

```bash
chsh -s "$(command -v zsh)"
```

如果刚安装了 `nvm` / `uv`，当前终端还不能识别命令，脚本会提示你根据当前 shell 执行对应的 `source` 命令，或者重新打开终端。
