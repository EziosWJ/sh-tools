#!/usr/bin/env bash
# Bash 会话菜单；所有操作只作用于明确选择的会话。

session_list() {
  local sessions
  sessions="$(tmux list-sessions -F '#{session_name} | #{session_windows} 个窗口 | 已连接客户端: #{session_attached}' 2>/dev/null)" || {
    info "没有可用会话（tmux 服务可能尚未启动）。"
    return 0
  }
  printf '%s\n' "$sessions"
}

session_pick() {
  local sessions name
  local names=()
  sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)" || {
    info "没有可用会话。" >&2
    return 0
  }
  while IFS= read -r name; do
    [[ -n "$name" ]] && names+=("$name")
  done <<< "$sessions"
  if (( ${#names[@]} == 0 )); then
    return 0
  fi
  select_option "选择会话：" "${names[@]}"
}

session_enter() {
  local name="$1"
  tmux has-session -t "=$name" 2>/dev/null || {
    error "会话不存在：$name"
    return 1
  }
  if in_tmux; then
    tmux switch-client -t "=$name"
  else
    tmux attach-session -t "=$name"
  fi
}

session_create() {
  local name="${1:-}" directory="${2:-$PWD}"
  if [[ -z "$name" ]]; then
    read -r -p "新会话名称（0 返回）: " name || return 0
    [[ "$name" == "0" ]] && return 0
    read -r -p "工作目录 [$PWD]（0 返回）: " directory || return 0
    [[ "$directory" == "0" ]] && return 0
    directory="${directory:-$PWD}"
  fi
  validate_session_name "$name" || return 1
  directory="$(resolve_path "$directory")"
  [[ -d "$directory" ]] || { error "目录不存在：$directory"; return 1; }
  if tmux has-session -t "=$name" 2>/dev/null; then
    error "会话已存在：$name，请选择进入会话。"
    return 1
  fi
  tmux new-session -d -s "$name" -c "$directory" || return 1
  if [[ "${3:-}" == "enter" ]]; then
    session_enter "$name"
    return $?
  fi
  success "已创建会话：$name；选择“进入会话”即可连接。"
}

session_rename() {
  local name="${1:-}" new_name="${2:-}"
  if [[ -z "$name" ]]; then
    name="$(session_pick)" || return 1
    [[ -n "$name" ]] || return 0
  fi
  if [[ -z "$new_name" ]]; then
    read -r -p "将 $name 重命名为（0 返回）: " new_name || return 0
    [[ "$new_name" == "0" ]] && return 0
  fi
  validate_session_name "$new_name" || return 1
  tmux rename-session -t "=$name" "$new_name" || return 1
  success "已重命名：$name → $new_name"
}

session_kill() {
  local name="${1:-}" answer
  if [[ -z "$name" ]]; then
    name="$(session_pick)" || return 1
    [[ -n "$name" ]] || return 0
  fi
  tmux has-session -t "=$name" 2>/dev/null || {
    error "会话不存在：$name"
    return 1
  }
  read -r -p "结束会话 $name 会终止其中的进程，确认？[y/N]: " answer || return 0
  case "$answer" in
    y|Y)
      tmux kill-session -t "=$name" || return 1
      success "已结束会话：$name"
      ;;
    *) info "已取消。" ;;
  esac
}

session_quick() {
  local selected sessions name
  local options
  while true; do
    options=('新建会话')
    sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)" || sessions=""
    while IFS= read -r name; do
      [[ -n "$name" ]] && options+=("会话 | $name")
    done <<< "$sessions"
    options+=('重命名会话' '结束会话' '快捷键帮助')
    selected="$(select_option 'tmux 会话' "${options[@]}")" || return 0
    case "$selected" in
      '') return 0 ;;
      '新建会话') session_create '' "$PWD" enter || error '创建或进入会话失败。' ;;
      '会话 | '*) session_enter "${selected#会话 | }" || error '进入会话失败。' ;;
      '重命名会话') session_rename || error '重命名失败。' ;;
      '结束会话') session_kill || error '结束会话失败。' ;;
      '快捷键帮助') show_session_help ;;
    esac
  done
}

session_menu() {
  if [[ -t 0 ]] && check_command fzf; then
    session_quick
    return
  fi
  local choice name
  while true; do
    printf '\ntmux 会话管理\n1) 列出会话\n2) 进入会话\n3) 新建会话\n4) 重命名会话\n5) 结束会话\n0) 返回上一级\n'
    read -r -p "请选择编号: " choice || return 0
    case "$choice" in
      1) session_list || error "列出会话失败。" ;;
      2)
        name="$(session_pick)" || { error "读取会话失败。"; continue; }
        if [[ -n "$name" ]]; then
          session_enter "$name" || error "进入会话失败。"
        fi
        ;;
      3) session_create || error "创建失败。" ;;
      4) session_rename || error "重命名失败。" ;;
      5) session_kill || error "结束会话失败。" ;;
      0) return 0 ;;
      *) error "输入无效。" ;;
    esac
  done
}

show_session_help() {
  printf '%s\n' \
    '用法: tmux-session [命令]' \
    '  无参数                   打开会话菜单' \
    '  list                     列出会话' \
    '  enter <名称>             进入已有会话' \
    '  create <名称> [目录]     新建会话' \
    '  rename <名称> <新名称>   重命名会话' \
    '  kill <名称>              确认后结束会话' \
    '进入会话后按 Ctrl+b，再按 d 挂起；从外部进入时会回到菜单。'
}

tmux_session_main() {
  local action="${1:-menu}"
  case "$action" in
    help|-h|--help) show_session_help; return 0 ;;
  esac
  check_command tmux || { error "请先安装 tmux：sudo apt install tmux"; return 1; }
  case "$action" in
    menu) session_menu ;;
    list) session_list ;;
    enter)
      [[ -n "${2:-}" ]] || { error "请指定会话名称。"; return 1; }
      session_enter "$2" ;;
    create) session_create "${2:-}" "${3:-$PWD}" ;;
    rename) session_rename "${2:-}" "${3:-}" ;;
    kill) session_kill "${2:-}" ;;
    *) error "未知命令：$action"; show_session_help; return 1 ;;
  esac
}
