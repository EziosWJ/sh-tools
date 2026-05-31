#!/usr/bin/env bash
# tmux会话管理模块
# 精简接口：快速切换、挂起、创建会话

# 切换到指定会话（不存在则创建）
session_goto() {
  local name="$1"
  local directory="${2:-$(pwd)}"

  if ! validate_session_name "$name"; then
    return 1
  fi

  if tmux has-session -t "$name" 2>/dev/null; then
    # 会话已存在，直接切换
    if in_tmux; then
      tmux switch-client -t "$name"
    else
      tmux attach -t "$name"
    fi
  else
    # 会话不存在，创建后切换
    directory=$(resolve_path "$directory")
    if [[ ! -d "$directory" ]]; then
      error "目录不存在: $directory"
      return 1
    fi
    tmux new-session -d -s "$name" -c "$directory"
    success "创建会话: $name"
    if in_tmux; then
      tmux switch-client -t "$name"
    else
      tmux attach -t "$name"
    fi
  fi
}

# 列出所有会话
session_list() {
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}" 2>/dev/null)

  if [[ -z "$sessions" ]]; then
    info "没有活动的会话"
    return 0
  fi

  echo ""

  while IFS='|' read -r name windows attached; do
    local attached_status=" "
    [[ "$attached" -gt 0 ]] && attached_status="[已连接]"
    printf "  %-20s %s\n" "$name" "${windows}个窗口  $attached_status"
  done <<< "$sessions"
  echo ""
}

# 交互式选择会话（无参数时调用）
session_quick() {
  if ! check_command fzf; then
    # 无 fzf 时退化为 list
    session_list
    return 0
  fi

  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

  local options=("➕ 创建新会话")
  if [[ -n "$sessions" ]]; then
    while IFS= read -r s; do
      [[ -n "$s" ]] && options+=("$s")
    done <<< "$sessions"
  fi

  local selected
  selected=$(printf '%s\n' "${options[@]}" | fzf --prompt="会话: " --height=40% --reverse --header="选择会话 或 创建新会话")

  if [[ -z "$selected" ]]; then
    return 0
  fi

  if [[ "$selected" == "➕ 创建新会话" ]]; then
    local name
    name=$(echo "" | fzf --prompt="新会话名称: " --height=30% --reverse --print-query | head -1)
    if [[ -n "$name" ]]; then
      session_goto "$name"
    fi
  else
    session_goto "$selected"
  fi
}

# 终止会话
session_kill() {
  local name="$1"

  if [[ -z "$name" ]]; then
    # 无参数时用 fzf 选择
    if ! check_command fzf; then
      error "用法: tmux-session kill <名称>"
      return 1
    fi
    local sessions
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    if [[ -z "$sessions" ]]; then
      info "没有活动的会话"
      return 0
    fi
    name=$(printf '%s\n' $sessions | fzf --prompt="终止哪个会话: " --height=40% --reverse)
    [[ -z "$name" ]] && return 0
  fi

  if ! tmux has-session -t "$name" 2>/dev/null; then
    error "会话 '$name' 不存在"
    return 1
  fi

  tmux kill-session -t "$name"
  success "已终止会话: $name"
}

# 重命名当前会话
session_rename() {
  local new_name="$1"

  if ! in_tmux; then
    error "需要在 tmux 内使用 rename"
    return 1
  fi

  if [[ -z "$new_name" ]]; then
    # 无参数时进入交互式重命名
    tmux command-prompt -I "#{session_name}" "rename-session -- '%%'"
    return 0
  fi

  if ! validate_session_name "$new_name"; then
    return 1
  fi

  local current
  current=$(tmux display-message -p '#{session_name}')
  tmux rename-session -t "$current" "$new_name"
  success "重命名: $current -> $new_name"
}

# 显示帮助信息
show_session_help() {
  cat <<EOF
用法: tmux-session [命令|会话名]

快捷的tmux会话管理。

用法:
  tmux-session              交互式选择/创建会话(需fzf)
  tmux-session <名称>       切换到会话，不存在则创建
  tmux-session ls           列出所有会话
  tmux-session kill [名称]  终止会话(无参数则交互选择)
  tmux-session rename [名称] 重命名当前会话

示例:
  tmux-session dev              # 切换到 dev 会话(没有则创建)
  tmux-session myproject        # 切换到 myproject
  tmux-session ls               # 查看所有会话
  tmux-session kill dev         # 终止 dev 会话
  tmux-session rename newname   # 重命名当前会话

提示:
  Ctrl+b d   挂起(detach)当前会话(会话在后台继续运行)
  tmux attach -t <名称>   从终端恢复已挂起的会话
EOF
}

# 主函数
tmux_session_main() {
  load_config

  local command="${1:-}"

  case "$command" in
    ls|list)
      session_list
      ;;
    kill)
      session_kill "${2:-}"
      ;;
    rename)
      session_rename "${2:-}"
      ;;
    -h|--help|help)
      show_session_help
      ;;
    "")
      session_quick
      ;;
    -*)
      error "未知选项: $command"
      show_session_help
      return 1
      ;;
    *)
      # 默认行为：当作会话名处理
      session_goto "$command" "${2:-}"
      ;;
  esac
}
