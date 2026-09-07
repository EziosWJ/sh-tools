# tmux 工具

Bash 会话工具，提供上下键选择会话和快捷键帮助。终端中安装了 `fzf` 时使用交互选择器，否则回退数字菜单；无需 jq 或额外配置文件。

## 直接使用

```bash
bash sh-tools.sh add-tmux-help
```

进入“会话管理”后可列出、进入、新建、重命名、结束会话；“快捷键帮助”按分类查看。每次操作后留在当前菜单，输入 `0` 返回上一级。输入结束（EOF）退出菜单。

运行 `tmux-session` 后，使用上下键选择会话、回车进入，也可以直接选择“新建会话”，填写名称和目录后自动进入。选择器中按 `0` 或 `Esc` 返回。数字菜单及 `create` 子命令仅创建、不自动进入。

进入后使用 `Ctrl+b`，再按 `d` 挂起：

- 从 tmux 外进入时，挂起后回到会话菜单。
- 从 tmux 内切换时，菜单仍在原会话的面板中，返回原会话可继续使用。
- 如果结束运行菜单自身的会话，该面板和菜单也会随之结束。

结束会话前必须确认，会终止会话中的进程。会话名称按完整名称匹配。

## 安装快捷命令

在工具菜单选择“安装命令”，或执行：

```bash
bash add-tmux-help/add-tmux-help.sh install
tmux-session
tmux-help -i
```

脚本把运行模块复制到 `~/.local/share/sh-tools/add-tmux-help/`，在 `~/.local/bin/` 创建命令。若 `.bashrc` / `.zshrc` 中存在旧安装器的 tmux 标记块，会先备份再改为调用独立命令，避免 zsh 直接执行 Bash 函数。无旧标记块时不添加 shell 配置。安装后重新打开终端，清除已加载的旧函数。

命令由 Bash 执行，可从其他 shell 调用。如果命令目录不在 PATH 中，安装器会提示完整路径。需要上下键选择时，可先安装 `fzf`（Debian / Ubuntu：`sudo apt install fzf`）。

## 常用命令

```bash
tmux-session list
tmux-session create dev /path/to/project
tmux-session enter dev
tmux-session rename dev work
tmux-session kill work
tmux-help session
tmux-help -s 分屏
```

`tmux-session` 无参数打开菜单；新建、选择和重命名提示中输入 `0` 取消并返回。直接传入子命令时执行一次并退出。

## 卸载

```bash
bash add-tmux-help/add-tmux-help.sh uninstall
```

卸载会删除带本工具标记的 v2 命令；对与 v1 生成模板完全一致的旧命令，会移动到命令目录中的 `.sh-tools-backup.*` 目录并打印备份路径。直接安装也会先备份这些旧命令，再安装 v2。未知来源的同名文件或软链接会保留并明确提示；安装在修改命令前检查全部目标。

运行时文件和所有会话保留。卸载也会备份并移除旧安装器留下的 tmux 标记块，其他 shell 配置保留；当前终端已加载的函数需重新打开终端才能清除。

远程执行方式见[首页](../README.md)。调试时可以用 `ADD_TMUX_HELP_RUNTIME_DIR`、`ADD_TMUX_HELP_BIN_DIR`、`ADD_TMUX_HELP_RC_DIR` 指向临时运行目录、命令目录和 shell 配置目录。
