#!/usr/bin/env bash
set -Eeuo pipefail

SKILLS_COMMAND=(npx skills@latest add mattpocock/skills)

info() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
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

check_prerequisites() {
  if ! command_exists node; then
    error "未找到 node，请先安装 Node.js。"
    return 1
  fi

  if ! command_exists npx; then
    error "未找到 npx，请先安装 npm/npx。"
    return 1
  fi

  info "环境检查："
  print_status "node" "$(node --version 2>/dev/null || command -v node)"
  print_status "npx" "$(npx --version 2>/dev/null || command -v npx)"
  print_status "cwd" "$(pwd)"
}

run_install() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    warn "当前不是交互式终端，skills 安装流程可能无法正常工作。"
  fi

  info "即将进入 mattpocock/skills 安装流程。后续步骤请直接在当前终端中操作。"
  printf '  %s\n' "${SKILLS_COMMAND[*]}"
  "${SKILLS_COMMAND[@]}"
}

main() {
  check_prerequisites
  run_install
}

main "$@"
