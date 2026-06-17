# init-Linux Roadmap

面向实际装机使用的功能扩展计划，目标是让 `init-linux.sh` 不只是“能装”，而是能在新机器上更快进入开发状态。

原则：

- 每一项能力都保持独立子命令，便于单独执行和验证
- 默认避免扩大 `all` 的行为范围
- 先补可观测性，再补高频工具和配置
- 新功能优先保持幂等

## Plan 1：状态盘点与验收（已完成）

目标：

- 扩展 `check`，输出更完整的环境和工具状态
- 让用户知道当前机器“已具备什么、缺什么、还差哪一步”

范围：

- 系统环境：`apt`、WSL、当前 shell、当前用户
- 核心工具：`curl`、`wget`、`git`、`zsh`
- 常用开发工具状态：`tmux`、`fzf`、`rg`、`jq`
- Shell 栈：Oh My Zsh、Powerlevel10k、rc 文件存在情况
- Node 栈：`nvm`、`node`、`npm`
- Python 栈：`uv`
- rc 配置状态：`nvm` 环境变量、`uv` PATH

验收：

- `bash init-linux.sh check` 能输出结构化状态摘要
- 用户可据此决定下一步执行 `deps`、`zsh`、`ohmyzsh`、`nvm`、`uv` 或 `env`

## Plan 2：开发工具包 `devtools`（已完成）

目标：

- 补齐一台开发机最常见的基础工具

候选包：

- `tmux`
- `fzf`
- `ripgrep`
- `jq`
- `tree`
- `zip`

验收：

- `bash init-linux.sh devtools` 能识别缺失项并安装
- 重复执行时已安装项自动跳过

## Plan 3：Git 初始化 `gitcfg`（已完成）

目标：

- 让 Git 从“已安装”变成“可直接提交”

范围：

- `user.name`
- `user.email`
- `init.defaultBranch`
- `core.editor`

验收：

- 新机器可快速完成最小 Git 初始化
- 已有配置时不会静默覆盖

## Plan 4：代理感知下载（已完成）

目标：

- 提升受限网络环境下的成功率

范围：

- 统一 `curl` 下载路径的代理感知
- 失败时给出明确的下一步提示

覆盖步骤：

- `mirror`
- `ohmyzsh`
- `nvm`
- `uv`

## Plan 5：Node 生态补全（已完成）

目标：

- 让 Node.js 环境安装后能更快开工

范围：

- `corepack enable`
- 可选启用 `pnpm`
- 输出 Node 生态验收结果

## Plan 6：Python 生态补全（已完成）

目标：

- 让 `uv` 配合系统 Python 更容易落地

范围：

- 检查并安装 `python3`
- 检查并安装 `python3-pip`
- 检查并安装 `python3-venv`

## Plan 7：SSH 初始化（已完成）

目标：

- 补齐 Git 平台接入前的本机准备

范围：

- 生成 `ed25519` key
- 检查 `~/.ssh` 权限
- 输出公钥位置和下一步提示

## Plan 8：WSL 专项优化（已完成）

目标：

- 把“支持 WSL”提升到“照顾 WSL”

范围：

- 检测 WSL 专项配置状态
- 提供 `wsl` 子命令处理建议或可选配置
