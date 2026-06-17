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
6. 不要自动切换默认 shell。
7. 不要自动创建 `~/.zshrc`。
8. 不要同时写入 `.bashrc` 和 `.zshrc`，只处理当前 shell 对应的配置文件。
9. 需要有清晰的日志输出。
10. 对 Debian 系以外系统只提醒用户，不强行继续。

## 支持的命令行参数

请至少支持以下参数：

```bash
bash init-ubuntu.sh
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

含义：

- 无参数：进入交互式菜单
- `all`：一键执行全部流程
- `check`：检测系统环境
- `mirror`：配置软件源
- `deps`：检查并安装基础依赖
- `zsh`：安装 zsh
- `ohmyzsh`：安装 Oh My Zsh
- `p10k`：安装 Powerlevel10k 主题
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

## 一键安装全部流程

`all` 的执行顺序必须固定为：

```text
1. 检测系统环境
2. 配置镜像源
3. apt update
4. 检查并安装基础依赖
5. 安装 zsh
6. 安装 Oh My Zsh
7. 安装 Powerlevel10k
8. 安装 nvm
9. 安装 Node.js LTS，并设置为 default
10. 安装 uv
11. 修复当前 shell 的环境变量
12. 输出结束提示
```

注意：

- `mirror` 使用 linuxmirror 脚本，单独交互执行，不要强行自动化输入。
- 如果 Oh My Zsh 或 shell 切换导致用户需要重新打开终端，脚本应支持用户之后重复执行，不应因为重复执行破坏配置。

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

执行：

```bash
sudo apt update
```

### install_deps

检查并安装基础依赖。

基础依赖至少包括：

```text
curl
wget
git
ca-certificates
unzip
tar
build-essential
```

逻辑要求：

1. 先检查哪些命令或包缺失。
2. 如果有缺失，提示用户。
3. 询问用户是否安装。
4. 用户确认后执行安装。
5. 如果用户拒绝，跳过并给出警告。

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
5. 镜像源配置完成后，`all` 流程中继续执行 `apt update`。

## 安装 zsh

实现 `install_zsh` 函数。

要求：

1. 检查 zsh 是否已安装。
2. 如果已安装，跳过。
3. 如果未安装，使用 apt 安装：

```bash
sudo apt install -y zsh
```

4. 不要自动执行 `chsh`。
5. 最后提示用户如需切换默认 shell，可手动执行：

```bash
chsh -s "$(command -v zsh)"
```

## 安装 Oh My Zsh

实现 `install_oh_my_zsh` 函数。

要求：

1. 检查 `~/.oh-my-zsh` 是否存在。
2. 如果存在，提示已安装并跳过。
3. 如果不存在，调用官方安装脚本：

```bash
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://install.ohmyz.sh)"
```

4. 不要自动切换 shell。
5. 不要自动创建 `~/.zshrc`。
6. 如果当前不是 zsh，也允许安装，但需要提示用户后续可以切换到 zsh。

## 安装 Powerlevel10k

实现 `install_powerlevel10k` 函数。

要求：

1. 安装路径为：

```bash
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

2. 如果目录已经存在，跳过 clone。
3. 如果不存在，执行：

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
```

4. 只有在 `~/.zshrc` 存在时，才修改主题配置。
5. 不要自动创建 `~/.zshrc`。
6. 如果 `~/.zshrc` 存在：
   - 如果已有 `ZSH_THEME=...`，替换为：

```bash
ZSH_THEME="powerlevel10k/powerlevel10k"
```

   - 如果没有 `ZSH_THEME=...`，追加：

```bash
ZSH_THEME="powerlevel10k/powerlevel10k"
```

7. 修改配置要避免重复写入。

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

1. 根据当前 shell 判断配置文件：
   - 如果当前 shell 是 zsh，处理 `~/.zshrc`
   - 如果当前 shell 是 bash，处理 `~/.bashrc`
   - 其他 shell 给出提示，不强行处理
2. 不要同时写入 `.bashrc` 和 `.zshrc`。
3. 不要自动创建 `.zshrc`。
4. 如果当前 shell 是 zsh，但 `~/.zshrc` 不存在，提示用户，不创建。
5. 如果当前 shell 是 bash，但 `~/.bashrc` 不存在，可以提示用户，不强行创建。
6. 检查 nvm 是否已安装：
   - 如果 `$HOME/.nvm/nvm.sh` 存在，则确保配置文件中有以下内容：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

7. 检查 uv 是否已安装：
   - 如果 `$HOME/.local/bin/uv` 存在，或者 `command -v uv` 可用，则确保配置文件中有：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

8. 所有写入必须避免重复。
9. 执行完后尝试 source 当前配置文件：
   - bash source `~/.bashrc`
   - zsh source `~/.zshrc`
10. source 失败时只提示警告，不要中断脚本。

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

1. 不重复 clone Powerlevel10k。
2. 不重复安装 Oh My Zsh。
3. 不重复写入 nvm 配置块。
4. 不重复写入 uv PATH。
5. 不重复追加 Powerlevel10k 主题配置。
6. 已安装软件应提示并跳过。
7. `.zshrc` 不存在时不能创建。

## 结束提示

脚本执行结束后，输出清晰提示：

```text
初始化流程已完成。

如果你安装了 zsh，但尚未切换默认 shell，可以手动执行：
chsh -s "$(command -v zsh)"

如果刚安装了 nvm / uv，但当前终端无法识别命令，请重新打开终端，或执行：
source ~/.bashrc
# 或
source ~/.zshrc
```

根据当前 shell，只提示对应的 source 命令即可。

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
