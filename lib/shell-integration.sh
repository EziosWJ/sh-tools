#!/usr/bin/env bash

shell_warn() {
  if declare -F warn >/dev/null 2>&1; then
    warn "$@"
  else
    printf '[WARN] %s\n' "$*" >&2
  fi
}

shell_error() {
  if declare -F error >/dev/null 2>&1; then
    error "$@"
  else
    printf '[ERROR] %s\n' "$*" >&2
  fi
}

shell_rc_files() {
  local rc_file
  local rc_files=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
  )

  for rc_file in "${rc_files[@]}"; do
    if [[ -f "$rc_file" ]]; then
      printf '%s\n' "$rc_file"
    else
      shell_warn "$rc_file 不存在，已跳过。"
    fi
  done
}

shell_append_line_if_missing() {
  local file="$1"
  local line="$2"

  if [[ ! -f "$file" ]]; then
    shell_warn "$file 不存在，已跳过写入。"
    return 1
  fi

  if grep -Fxq "$line" "$file"; then
    return 0
  fi

  if ! printf '\n%s\n' "$line" >> "$file"; then
    shell_error "写入 $file 失败。"
    return 1
  fi
}

shell_replace_marked_block() {
  local file="$1"
  local marker_start="$2"
  local marker_end="$3"
  local block="$4"

  if [[ ! -f "$file" ]]; then
    shell_warn "$file 不存在，已跳过写入。"
    return 1
  fi

  if grep -qF "$marker_start" "$file"; then
    sed -i "/$marker_start/,/$marker_end/d" "$file"
  fi

  if ! printf '\n%s\n' "$block" >> "$file"; then
    shell_error "写入 $file 失败。"
    return 1
  fi
}

shell_remove_marked_block() {
  local file="$1"
  local marker_start="$2"
  local marker_end="$3"

  if [[ ! -f "$file" ]]; then
    shell_warn "$file 不存在，已跳过。"
    return 1
  fi

  if ! grep -qF "$marker_start" "$file"; then
    return 0
  fi

  sed -i "/$marker_start/,/$marker_end/d" "$file"
}

shell_source_current_rc() {
  local shell_name="${1:-$(basename "${SHELL:-}")}"
  local rc_file

  case "$shell_name" in
    bash) rc_file="$HOME/.bashrc" ;;
    zsh) rc_file="$HOME/.zshrc" ;;
    *)
      shell_warn "当前 shell 为 ${shell_name:-未知}，已跳过自动 source，请重新打开终端。"
      return 0
      ;;
  esac

  if [[ ! -f "$rc_file" ]]; then
    shell_warn "$rc_file 不存在，已跳过自动 source。"
    return 0
  fi

  if [[ "$shell_name" == "bash" ]]; then
    # shellcheck disable=SC1090
    source "$rc_file" || shell_warn "source $rc_file 失败，请稍后手动 source 或重新打开终端。"
  else
    zsh -c 'source "$1"' _ "$rc_file" >/dev/null 2>&1 || shell_warn "source $rc_file 失败，请稍后手动 source 或重新打开终端。"
  fi
}
