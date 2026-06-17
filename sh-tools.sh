#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"

if [[ -f "$SCRIPT_DIR/lib/tool-registry.sh" ]]; then
  source "$SCRIPT_DIR/lib/tool-registry.sh"
elif source <(curl -fsSL "$REPO_RAW_BASE/lib/tool-registry.sh") 2>/dev/null; then
  :
fi

if ! declare -F tool_registry_names >/dev/null 2>&1; then
  tool_registry_names() {
    printf '%s\n' \
      "init-Linux" \
      "add-tmux-help" \
      "proxyctl" \
      "install-karpathy-skills" \
      "agents" \
      "skills"
  }
fi

if ! declare -F tool_registry_description >/dev/null 2>&1; then
  tool_registry_description() {
    local tool="$1"

    case "$tool" in
      init-Linux)
        printf '%s\n' "Debian 系 Linux 开发环境初始化脚本（含 WSL 增强）"
        ;;
      add-tmux-help)
        printf '%s\n' "向 shell 配置添加 tmux 快捷键帮助函数"
        ;;
      proxyctl)
        printf '%s\n' "代理管理工具，一键管理 Shell/Git/NPM/APT 代理"
        ;;
      install-karpathy-skills)
        printf '%s\n' "下载 CLAUDE.md 并创建 AGENTS.md 软链接"
        ;;
      agents)
        printf '%s\n' "AI agent 工具安装入口，支持 Codex、Claude Code、OpenCode、Hermes、Pi Agent"
        ;;
      skills)
        printf '%s\n' "skills 安装入口，二级选择具体 provider"
        ;;
      *)
        return 1
        ;;
    esac
  }
fi

if ! declare -F tool_registry_local_entry >/dev/null 2>&1; then
  tool_registry_local_entry() {
    local tool="$1"

    case "$tool" in
      init-Linux)
        printf '%s\n' "init-Linux/init-linux.sh"
        ;;
      add-tmux-help)
        printf '%s\n' "add-tmux-help/add-tmux-help.sh"
        ;;
      proxyctl)
        printf '%s\n' "proxyctl/proxyctl.sh"
        ;;
      install-karpathy-skills)
        printf '%s\n' "install-karpathy-skills/install-karpathy-skills.sh"
        ;;
      agents)
        printf '%s\n' "agents/agents.sh"
        ;;
      skills)
        printf '%s\n' "skills/skills.sh"
        ;;
      *)
        return 1
        ;;
    esac
  }
fi

if ! declare -F tool_registry_remote_entry >/dev/null 2>&1; then
  tool_registry_remote_entry() {
    tool_registry_local_entry "$1"
  }
fi

if ! declare -F tool_registry_menu_command_count >/dev/null 2>&1; then
  tool_registry_menu_command_count() {
    local tool="$1"

    case "$tool" in
      proxyctl)
        printf '%s\n' "11"
        ;;
      init-Linux|add-tmux-help|install-karpathy-skills|agents|skills)
        printf '%s\n' "0"
        ;;
      *)
        return 1
        ;;
    esac
  }
fi

if ! declare -F tool_registry_menu_command_label >/dev/null 2>&1; then
  tool_registry_menu_command_label() {
    local tool="$1"
    local index="$2"

    case "$tool:$index" in
      proxyctl:1) printf '%s\n' "on" ;;
      proxyctl:2) printf '%s\n' "off" ;;
      proxyctl:3) printf '%s\n' "apt-on" ;;
      proxyctl:4) printf '%s\n' "apt-off" ;;
      proxyctl:5) printf '%s\n' "docker-on" ;;
      proxyctl:6) printf '%s\n' "docker-off" ;;
      proxyctl:7) printf '%s\n' "docker-status" ;;
      proxyctl:8) printf '%s\n' "pip-on" ;;
      proxyctl:9) printf '%s\n' "pip-off" ;;
      proxyctl:10) printf '%s\n' "pip-status" ;;
      proxyctl:11) printf '%s\n' "status" ;;
      *)
        return 1
        ;;
    esac
  }
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
