#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
source "$SCRIPT_DIR/lib/tool-registry.sh"

usage() {
  echo "用法："
  echo "  bash sh-tools.sh"
  echo "  bash sh-tools.sh menu"
  echo "  bash sh-tools.sh list"

  local tool
  while IFS= read -r tool; do
    echo "  bash sh-tools.sh $tool [args...]"
  done < <(tool_registry_names)
}

has_local_tool() {
  local tool="$1"
  local entry

  entry="$(tool_registry_local_entry "$tool")" || return 1
  [[ -f "$SCRIPT_DIR/$entry" ]]
}

run_remote_bash_script() {
  local url="$1"
  shift || true
  bash <(curl -fsSL "$url") "$@"
}

run_remote_tool() {
  local tool="$1"
  shift || true
  local entry

  entry="$(tool_registry_remote_entry "$tool")" || {
    printf '未知工具：%s\n\n' "$tool" >&2
    usage
    return 1
  }

  if [[ "$tool" == "proxyctl" ]] && (($# > 0)); then
    bash <(curl -fsSL "$REPO_RAW_BASE/$entry") "$@"
    return 0
  fi

  run_remote_bash_script "$REPO_RAW_BASE/$entry" "$@"
}

run_tool() {
  local tool="$1"
  shift || true
  local entry

  if has_local_tool "$tool"; then
    entry="$(tool_registry_local_entry "$tool")"
    bash "$SCRIPT_DIR/$entry" "$@"
    return 0
  fi

  run_remote_tool "$tool" "$@"
}

print_tool_list() {
  tool_registry_names
}

show_menu() {
  local index=1
  local tool
  local description

  echo "请选择工具："
  echo ""

  while IFS= read -r tool; do
    description="$(tool_registry_description "$tool")"
    printf '%s) %s - %s\n' "$index" "$tool" "$description"
    index=$((index + 1))
  done < <(tool_registry_names)

  printf '%s) %s\n' "$index" "列出工具"
  echo "0) 退出"
}

menu_pick_tool_by_index() {
  local target_index="$1"
  local current_index=1
  local tool

  while IFS= read -r tool; do
    if [[ "$current_index" == "$target_index" ]]; then
      printf '%s\n' "$tool"
      return 0
    fi
    current_index=$((current_index + 1))
  done < <(tool_registry_names)

  return 1
}

prompt_tool_commands() {
  local tool="$1"
  local count
  local index
  local command
  local selected

  count="$(tool_registry_menu_command_count "$tool")" || return 1
  if [[ "$count" == "0" ]]; then
    run_tool "$tool"
    return 0
  fi

  echo "请选择 $tool 命令："
  echo ""
  for ((index = 1; index <= count; index++)); do
    command="$(tool_registry_menu_command_label "$tool" "$index")"
    printf '%s) %s\n' "$index" "$command"
  done
  echo "0) 返回"

  read -r -p "请输入选项编号: " selected || return 0

  if [[ "$selected" == "0" ]]; then
    return 0
  fi
  if [[ ! "$selected" =~ ^[0-9]+$ ]] || ((selected < 1 || selected > count)); then
    printf '无效选项，请输入 0-%s。\n' "$count" >&2
    return 1
  fi

  command="$(tool_registry_menu_command_label "$tool" "$selected")"
  run_tool "$tool" "$command"
}

interactive_menu() {
  local choice
  local tool
  local tool_count

  tool_count="$(tool_registry_names | wc -l | tr -d ' ')"

  while true; do
    printf '\n'
    show_menu
    read -r -p "请输入选项编号: " choice || return 0

    if [[ "$choice" == "0" ]]; then
      return 0
    fi
    if [[ "$choice" == "$((tool_count + 1))" ]]; then
      print_tool_list
      continue
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
      printf '无效选项，请输入 0-%s。\n' "$((tool_count + 1))" >&2
      continue
    fi

    tool="$(menu_pick_tool_by_index "$choice")" || {
      printf '无效选项，请输入 0-%s。\n' "$((tool_count + 1))" >&2
      continue
    }
    prompt_tool_commands "$tool"
  done
}

is_registered_tool() {
  local target="$1"
  local tool

  while IFS= read -r tool; do
    if [[ "$tool" == "$target" ]]; then
      return 0
    fi
  done < <(tool_registry_names)

  return 1
}

main() {
  local command="${1:-menu}"

  case "$command" in
    menu)
      interactive_menu
      ;;
    list)
      print_tool_list
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      if is_registered_tool "$command"; then
        shift
        run_tool "$command" "$@"
        return 0
      fi

      printf '未知命令：%s\n\n' "$command" >&2
      usage
      return 1
      ;;
  esac
}

main "$@"
