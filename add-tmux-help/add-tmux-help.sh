#!/usr/bin/env bash
set -Eeuo pipefail

MARKER="# >>> tmux-help >>>"

info() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
}

TMUX_HELP_FUNC='
# >>> tmux-help >>>
tmux-help() {
  cat <<'\''EOF'\''
tmux 常用快捷键：

前缀键：Ctrl+b

会话：
  Ctrl+b d      挂起/退出会话

窗口：
  Ctrl+b c      新建窗口
  Ctrl+b n      下一个窗口
  Ctrl+b p      上一个窗口
  Ctrl+b w      窗口列表
  Ctrl+b ,      重命名窗口
  Ctrl+b &      关闭窗口

面板：
  Ctrl+b %      左右分屏
  Ctrl+b "      上下分屏
  Ctrl+b 方向键 切换面板
  Ctrl+b z      面板全屏/恢复
  Ctrl+b x      关闭面板
  Ctrl+b q      显示面板编号

复制滚动：
  Ctrl+b [      进入滚动模式
  q             退出滚动模式
EOF
}
# <<< tmux-help <<<
'

add_to_rc() {
  local rc_file="$1"

  if [[ ! -f "$rc_file" ]]; then
    warn "$rc_file 不存在，跳过"
    return
  fi

  if grep -qF "$MARKER" "$rc_file"; then
    info "$rc_file 中已存在 tmux-help，跳过"
    return
  fi

  printf '\n%s\n' "$TMUX_HELP_FUNC" >> "$rc_file"
  success "已添加 tmux-help 到 $rc_file"
}

info "开始安装 tmux-help..."

add_to_rc "$HOME/.bashrc"
add_to_rc "$HOME/.zshrc"

success "完成！请执行 source ~/.bashrc 或 source ~/.zshrc 使生效"
