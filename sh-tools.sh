#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"

if [[ -f "$SCRIPT_DIR/lib/tool-registry.sh" ]]; then
  source "$SCRIPT_DIR/lib/tool-registry.sh"
else
  registry="$(curl -fsSL "$REPO_RAW_BASE/lib/tool-registry.sh")"
  source /dev/stdin <<< "$registry"
fi

usage() {
  echo "SH-TOOLS"
  echo "  我的个人 shell / agent 工具箱。"
  echo "  目标是让新机器初始化、agent 安装和 skills 接入更直接。"
  echo ""
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
  local script status=0
  script="$(mktemp)" || return 1
  if ! curl -fsSL "$url" -o "$script"; then
    rm -f -- "$script"
    printf '下载失败：%s\n' "$url" >&2
    return 1
  fi
  bash "$script" "$@" || status=$?
  rm -f -- "$script"
  return "$status"
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

  run_remote_bash_script "$REPO_RAW_BASE/$entry" "$@"
}

run_tool() {
  local tool="$1"
  shift || true
  local entry

  if has_local_tool "$tool"; then
    entry="$(tool_registry_local_entry "$tool")"
    bash "$SCRIPT_DIR/$entry" "$@"
    return $?
  fi

  run_remote_tool "$tool" "$@"
}

print_tool_list() {
  tool_registry_names
}

show_intro() {
  echo "SH-TOOLS"
  echo "  个人 shell / agent 工具箱"
  echo "  支持本地仓库执行，也支持远程单文件入口"
  echo ""
  echo "推荐路径："
  echo "  1. 新 Debian / Ubuntu / WSL 环境先跑 init-Linux"
  echo "  2. 再按需安装 agents"
  echo "  3. 最后补充 skills"
  echo ""
}

show_menu() {
  local index=1
  local tool
  local description

  show_intro
  echo "请选择工具："
  echo ""

  while IFS= read -r tool; do
    description="$(tool_registry_description "$tool")"
    printf '%s) %s - %s\n' "$index" "$tool" "$description"
    index=$((index + 1))
  done < <(tool_registry_names)

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

interactive_menu() {
  local choice
  local tool
  while true; do
    printf '\n'
    show_menu
    read -r -p "请输入选项编号: " choice || return 0

    if [[ "$choice" == "0" ]]; then
      return 0
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
      printf '无效选项，请输入 0-%s。\n' "$(tool_registry_names | wc -l | tr -d ' ')" >&2
      continue
    fi

    tool="$(menu_pick_tool_by_index "$choice")" || {
      printf '无效选项，请输入 0-%s。\n' "$(tool_registry_names | wc -l | tr -d ' ')" >&2
      continue
    }
    run_tool "$tool" || printf '操作失败，请检查上方错误后重试。\n' >&2
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
