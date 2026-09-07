#!/usr/bin/env bash

info() { printf '[INFO] %s\n' "$*"; }
success() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
check_command() { command -v "$1" >/dev/null 2>&1; }
in_tmux() { [[ -n "${TMUX:-}" ]]; }
resolve_path() { printf '%s\n' "${1/#\~/$HOME}"; }

validate_session_name() {
  if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ || "$1" == "0" ]]; then
    error "名称只能包含字母、数字、下划线和短横线，且不能为 0（返回键）。"
    return 1
  fi
}

# 菜单文字写入 stderr，stdout 只返回选中值。
select_option() {
  local prompt="$1" choice i
  shift
  local options=("$@")
  if [[ -t 0 ]] && check_command fzf; then
    printf '%s\n' "${options[@]}" '0) 返回上一级' |
      fzf --height=80% --layout=reverse --prompt="$prompt " \
        --header='↑↓ 选择 · Enter 确认 · 0 / Esc 返回' --bind='0:abort' |
      sed '/^0) 返回上一级$/d'
    return 0
  fi
  while true; do
    printf '%s\n' "$prompt" >&2
    for i in "${!options[@]}"; do
      printf '  %s) %s\n' "$((i + 1))" "${options[$i]}" >&2
    done
    printf '  0) 返回上一级\n请选择编号: ' >&2
    read -r choice || return 0
    [[ "$choice" == "0" ]] && return 0
    for i in "${!options[@]}"; do
      if [[ "$choice" == "$((i + 1))" ]]; then
        printf '%s\n' "${options[$i]}"
        return 0
      fi
    done
    error "输入无效。"
  done
}
