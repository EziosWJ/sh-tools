# add-tmux-help

向 shell 配置添加 `tmux-help` 函数，在终端中快速查看 tmux 常用快捷键。

## 功能

- 在 `~/.bashrc` 和 `~/.zshrc` 中注入 `tmux-help` 函数
- 使用标记注释避免重复注入，可安全多次执行
- 同时支持 bash 和 zsh

安装后在终端输入 `tmux-help` 即可查看快捷键速查表。

## 使用方式

### 本地执行

```bash
bash add-tmux-help.sh
```

### 一键远程执行

```bash
curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/add-tmux-help/add-tmux-help.sh | bash
```

执行后重新加载 shell 配置使其生效：

```bash
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```
