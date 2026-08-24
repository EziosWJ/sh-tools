# Codex Prompt：生成 Debian 系 Linux 初始化脚本

你是一名经验丰富的 Linux 运维工程师和 Bash 脚本开发者。请根据以下需求，实现一个 Debian 系 Linux 初始化脚本。

## 目标

实现一个通用快捷脚本，用于我在新安装 Debian 系 Linux 或其 WSL 环境后，快速完成常用开发环境初始化。

脚本名称建议为：

```bash
init-ubuntu.sh
```

该脚本不是追求完全无人值守，而是追求：

- 可选择执行某一项
- 可一键安装全部
- 可重复执行
- 能检测并修复 nvm / uv 环境变量
- 适合 Debian 系 Linux 场景，WSL 作为可选增强

## 基本要求

1. 使用 Bash 编写。
2. 支持交互式菜单。
3. 支持命令行参数模式。
4. 所有功能必须封装为函数。
5. 脚本应尽量具备幂等性，重复执行不能重复写入配置。
6. 只处理 `~/.bashrc`，不随意创建配置文件。
7. 需要有清晰的日志输出。
8. 对 Debian 系以外系统只提醒用户，不强行继续。

## 支持的命令行参数

请至少支持以下参数：

```bash
bash init-ubuntu.sh
bash init-ubuntu.sh all
bash init-ubuntu.sh check
bash init-ubuntu.sh mirror
bash init-ubuntu.sh deps
bash init-ubuntu.sh deps build
bash init-ubuntu.sh deps diagnose
bash init-ubuntu.sh nvm
bash init-ubuntu.sh node
bash init-ubuntu.sh uv
bash init-ubuntu.sh env
```

含义：

- 无参数：进入交互式菜单
- `all`：一键执行全部流程
- `check`：检测系统环境
- `mirror`：配置软件源
- `deps`：安装核心、推荐依赖，并可选择可选依赖组
- `deps build`：安装编译扩展依赖组
- `deps diagnose`：安装诊断与同步依赖组
- `nvm`：安装 nvm
- `node`：安装 Node.js LTS，并设置为默认版本
- `uv`：安装 uv
- `env`：修复当前 shell 配置文件中的 nvm / uv 环境变量

## 交互式菜单

执行：

```bash
bash init-ubuntu.sh
```

时显示菜单，例如：

```text
请选择要执行的操作：

1) 检测系统环境
2) 配置软件源
3) 检查并安装依赖（核心、推荐、可选）
4) 安装 nvm
5) 安装 Node.js LTS
6) 安装 uv
7) 修复 nvm / uv 环境变量
8) 一键安装全部
0) 退出
```

## 一键安装全部流程

`all` 的执行顺序必须固定为：

```text
1. 检测系统环境
2. apt update
3. 安装核心必需依赖
4. 安装推荐依赖
5. 安装 nvm
6. 安装 Node.js LTS，并设置为 default
7. 安装 uv
8. 修复 ~/.bashrc 中的环境变量
9. 输出结束提示
```

注意：

- `mirror` 使用 linuxmirror 脚本，必须单独交互执行，不要放入 `all`，也不要强行自动化输入。

## 系统检测要求

实现 `check_system` 函数。

要求：

1. 检测当前系统是否有 `apt`。
2. 如果没有 `apt`，提示当前脚本主要支持 Debian 系发行版，并提供 WSL 可选增强。
3. 检测是否为 WSL 环境。
4. 输出当前系统信息，例如：
   - `uname -a`
   - 是否 WSL
   - 当前 shell
   - 当前用户
5. 不要自动退出太激进，主要起到提醒用户作用；但对于明显不支持 apt 的系统，后续安装类操作应中止。

## 日志函数

请实现以下日志函数：

- `info`
- `success`
- `warn`
- `error`

输出需要清晰、易读。

## apt 相关要求

实现以下函数：

- `apt_update`
- `install_deps`

### apt_update

脚本应兼容 root 直接执行和普通用户通过 `sudo` 执行。

### install_deps

检查并安装分层依赖：

- 核心必需：`curl`、`ca-certificates`、`git`、`tar`、`xz-utils`
- 推荐：`openssh-client`、`wget`、`unzip`、`file`、`less`
- 可选编译扩展：`build-essential`、`pkg-config`、`python3-dev`
- 可选诊断与同步：`lsof`、`dnsutils`、`netcat-openbsd`、`rsync`

逻辑要求：

1. 先检查哪些命令或包缺失。
2. 如果有缺失，提示用户。
3. 核心必需依赖不能跳过；推荐与可选依赖必须询问用户确认。
4. 用户确认后执行安装。
5. 如果用户拒绝推荐或可选依赖，跳过并给出警告。

## 配置软件源

实现 `setup_mirror` 函数。

使用：

```bash
bash <(curl -sSL https://linuxmirrors.cn/main.sh)
```

要求：

1. 单独启动 linuxmirror 交互式脚本。
2. 不要使用 expect。
3. 不要强行自动输入选项。
4. 在执行前提示用户一般建议：
   - 选择清华大学源
   - 使用 HTTP
   - 不更新软件包
5. 配置镜像源后，由用户单独执行 `apt update` 或后续 `all` 流程。

## 安装 nvm

实现 `install_nvm` 函数。

使用版本：

```text
v0.40.4
```

安装命令：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
```

要求：

1. 检查 `$HOME/.nvm/nvm.sh` 是否存在。
2. 如果存在，提示 nvm 已安装并跳过安装脚本。
3. 如果不存在，执行安装脚本。
4. 安装后调用 `fix_shell_env`，确保当前 shell 对应的配置文件包含 nvm 环境变量。
5. 然后在当前脚本中加载 nvm：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

## 安装 Node.js LTS

实现 `install_node_lts` 函数。

要求：

1. 执行前确保 nvm 可用。
2. 如果 nvm 不可用，尝试加载：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

3. 如果仍不可用，提示用户先安装 nvm。
4. 如果可用，执行：

```bash
nvm install --lts
nvm alias default 'lts/*'
nvm use default
```

5. 最后输出：

```bash
node -v
npm -v
```

## 安装 uv

实现 `install_uv` 函数。

安装命令：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

要求：

1. 如果 `uv` 命令已经存在，提示已安装并输出版本。
2. 如果不存在，执行安装脚本。
3. 安装后调用 `fix_shell_env`，确保当前 shell 对应配置文件包含：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

4. 在当前脚本中临时加载：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

5. 最后输出：

```bash
uv --version
```

## 修复环境变量

实现 `fix_shell_env` 函数。

这是重点功能。

要求：

1. 只处理已存在的 `~/.bashrc`，不自动创建。
2. 检查 nvm 是否已安装：
   - 如果 `$HOME/.nvm/nvm.sh` 存在，则确保配置文件中有以下内容：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

3. 检查 uv 是否已安装：
   - 如果 `$HOME/.local/bin/uv` 存在，或者 `command -v uv` 可用，则确保配置文件中有：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

4. 所有写入必须避免重复。
5. 不自动 source 配置文件，只提示用户手动执行 `source ~/.bashrc`。

## 辅助函数

请实现一个通用函数，例如：

```bash
append_if_missing FILE TEXT
```

要求：

1. 如果文件不存在，按前面的规则处理，不随意创建。
2. 如果文件中已经包含对应内容，不重复追加。
3. 如果不存在，则追加。

也可以实现更细粒度的函数，例如：

- `ensure_line_in_file`
- `ensure_block_in_file`

## 幂等性要求

重复执行脚本时：

1. 不重复写入 nvm 配置块。
2. 不重复写入 uv PATH。
3. 已安装软件应提示并跳过。
4. `.bashrc` 不存在时不能创建。

## 结束提示

脚本执行结束后，输出清晰提示：

```text
初始化流程已完成。

如果刚安装了 nvm / uv，但当前终端无法识别命令，请重新打开终端，或执行：
source ~/.bashrc
```

脚本只提示 `source ~/.bashrc`。

## 代码质量要求

1. Bash 代码要清晰可读。
2. 使用函数组织逻辑。
3. 尽量避免重复代码。
4. 对危险操作给出提示。
5. 不使用 expect。
6. 不使用 pip、poetry、conda。
7. 对用户输入要做基本校验。
8. 尽量使用 `command -v` 做命令检测。
9. 脚本开头可以使用：

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

但如果某些场景容易因为 source 或检测命令失败导致脚本退出，需要合理处理。

## 输出要求

请直接生成完整的 `init-ubuntu.sh` 脚本代码。
