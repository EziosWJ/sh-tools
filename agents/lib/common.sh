#!/usr/bin/env bash

if [[ -n "${SH_TOOLS_AGENTS_COMMON_LOADED:-}" ]]; then
  return 0
fi
SH_TOOLS_AGENTS_COMMON_LOADED=1

info() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
}

error() {
  printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_status() {
  local label="$1"
  local value="$2"
  printf '  %-18s %s\n' "$label" "$value"
}

command_version_line() {
  local command_name="$1"

  if ! command_exists "$command_name"; then
    return 1
  fi

  "$command_name" --version 2>/dev/null | head -n 1 || "$command_name" -v 2>/dev/null | head -n 1 || true
}

report_binary_status() {
  local label="$1"
  local command_name="$2"
  local version_line

  if ! command_exists "$command_name"; then
    print_status "$label" "missing"
    return 1
  fi

  version_line="$(command_version_line "$command_name")"
  if [[ -n "$version_line" ]]; then
    print_status "$label" "$version_line"
  else
    print_status "$label" "$(command -v "$command_name")"
  fi
}

report_path_status() {
  local label="$1"
  local path="$2"

  if [[ -e "$path" ]]; then
    print_status "$label" "$path"
  else
    print_status "$label" "missing: $path"
  fi
}

report_env_status() {
  local label="$1"
  local env_name="$2"
  local value="${!env_name:-}"

  if [[ -n "$value" ]]; then
    print_status "$label" "$value"
  else
    print_status "$label" "unset"
  fi
}

print_command() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
}

confirm() {
  local prompt="${1:-是否继续？}"
  local answer

  read -r -p "${prompt} [y/N]: " answer || return 1
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

require_commands() {
  local missing=0
  local command_name

  for command_name in "$@"; do
    if ! command_exists "$command_name"; then
      error "未找到命令：$command_name"
      missing=1
    fi
  done

  return "$missing"
}

warn_if_not_tty() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    warn "当前不是交互式终端，安装流程可能无法正常工作。"
  fi
}

bootstrap_agents_common() {
  local script_dir="$1"
  local repo_raw_base="$2"
  local runtime_dir="$3"
  local common_path

  if [[ -f "$script_dir/../lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$script_dir/../lib/common.sh"
    return 0
  fi

  common_path="$runtime_dir/lib/common.sh"
  if [[ ! -f "$common_path" ]]; then
    mkdir -p "$(dirname "$common_path")"
    curl -fsSL -o "$common_path" "$repo_raw_base/agents/lib/common.sh"
  fi
  # shellcheck disable=SC1090
  source "$common_path"
}
