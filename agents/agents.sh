#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
RUNTIME_DIR="${SH_TOOLS_AGENTS_RUNTIME_DIR:-$HOME/.local/share/sh-tools/agents}"

if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/lib/common.sh"
else
  mkdir -p "$RUNTIME_DIR/lib"
  curl -fsSL -o "$RUNTIME_DIR/lib/common.sh" "$REPO_RAW_BASE/agents/lib/common.sh"
  # shellcheck disable=SC1090
  source "$RUNTIME_DIR/lib/common.sh"
fi

provider_names() {
  printf '%s\n' \
    "codex" \
    "claude-code" \
    "opencode" \
    "hermes" \
    "pi-agent"
}

provider_description() {
  local provider="$1"

  case "$provider" in
    codex)
      printf '%s\n' "OpenAI Codex CLI 安装入口"
      ;;
    claude-code)
      printf '%s\n' "Anthropic Claude Code 安装入口"
      ;;
    opencode)
      printf '%s\n' "OpenCode 安装入口"
      ;;
    hermes)
      printf '%s\n' "Nous Hermes Agent 安装入口"
      ;;
    pi-agent)
      printf '%s\n' "Earendil Pi Agent 安装入口"
      ;;
    *)
      return 1
      ;;
  esac
}

provider_local_entry() {
  local provider="$1"

  case "$provider" in
    codex)
      printf '%s\n' "providers/codex.sh"
      ;;
    claude-code)
      printf '%s\n' "providers/claude-code.sh"
      ;;
    opencode)
      printf '%s\n' "providers/opencode.sh"
      ;;
    hermes)
      printf '%s\n' "providers/hermes.sh"
      ;;
    pi-agent)
      printf '%s\n' "providers/pi-agent.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

download_remote_file() {
  local remote_path="$1"
  local target_file="$2"

  mkdir -p "$(dirname "$target_file")"
  curl -fsSL -o "$target_file" "$REPO_RAW_BASE/agents/$remote_path"
}

provider_script_path() {
  local provider="$1"
  local entry

  entry="$(provider_local_entry "$provider")" || return 1
  if [[ -f "$SCRIPT_DIR/$entry" ]]; then
    printf '%s\n' "$SCRIPT_DIR/$entry"
    return 0
  fi

  local runtime_path="$RUNTIME_DIR/$entry"
  if [[ ! -f "$runtime_path" ]]; then
    download_remote_file "$entry" "$runtime_path"
    chmod +x "$runtime_path"
  fi
  printf '%s\n' "$runtime_path"
}

run_provider() {
  local provider="$1"
  shift || true
  local script_path

  script_path="$(provider_script_path "$provider")" || {
    printf '未知 agent provider：%s\n\n' "$provider" >&2
    usage
    return 1
  }

  bash "$script_path" "$@"
}

usage() {
  echo "用法："
  echo "  bash agents/agents.sh"
  echo "  bash agents/agents.sh list"
  echo "  bash agents/agents.sh status"
  echo "  bash agents/agents.sh doctor-all"

  local provider
  while IFS= read -r provider; do
    echo "  bash agents/agents.sh $provider [action]"
  done < <(provider_names)
}

print_provider_list() {
  provider_names
}

show_menu() {
  local index=1
  local provider
  local description

  echo "请选择 agent 工具："
  echo ""

  while IFS= read -r provider; do
    description="$(provider_description "$provider")"
    printf '%s) %s - %s\n' "$index" "$provider" "$description"
    index=$((index + 1))
  done < <(provider_names)

  printf '%s) %s\n' "$index" "status - 查看全部 agent 安装摘要"
  index=$((index + 1))
  printf '%s) %s\n' "$index" "doctor-all - 逐个执行 doctor"
  echo "0) 退出"
}

pick_provider_by_index() {
  local target_index="$1"
  local current_index=1
  local provider

  while IFS= read -r provider; do
    if [[ "$current_index" == "$target_index" ]]; then
      printf '%s\n' "$provider"
      return 0
    fi
    current_index=$((current_index + 1))
  done < <(provider_names)

  return 1
}

run_menu() {
  local selected
  local provider
  local provider_count

  provider_count="$(provider_names | wc -l | tr -d ' ')"
  show_menu
  echo ""
  read -r -p "请输入选项编号: " selected || return 0

  if [[ "$selected" == "0" ]]; then
    return 0
  fi
  if [[ ! "$selected" =~ ^[0-9]+$ ]]; then
    echo "输入无效。"
    return 1
  fi
  if [[ "$selected" == "$((provider_count + 1))" ]]; then
    show_status
    return 0
  fi
  if [[ "$selected" == "$((provider_count + 2))" ]]; then
    doctor_all
    return 0
  fi

  provider="$(pick_provider_by_index "$selected")" || {
    echo "输入无效。"
    return 1
  }

  run_provider "$provider"
}

provider_binary_name() {
  case "$1" in
    codex) printf '%s\n' "codex" ;;
    claude-code) printf '%s\n' "claude" ;;
    opencode) printf '%s\n' "opencode" ;;
    hermes) printf '%s\n' "hermes" ;;
    pi-agent) printf '%s\n' "pi" ;;
    *) return 1 ;;
  esac
}

provider_config_dir() {
  case "$1" in
    codex) printf '%s\n' "$HOME/.codex" ;;
    claude-code) printf '%s\n' "$HOME/.claude" ;;
    opencode) printf '%s\n' "$HOME/.config/opencode" ;;
    hermes) printf '%s\n' "$HOME/.hermes" ;;
    pi-agent) printf '%s\n' "$HOME/.pi" ;;
    *) return 1 ;;
  esac
}

show_status() {
  local provider
  local binary_name
  local config_dir
  local installed
  local version_line
  local config_state

  printf '%-14s %-10s %-12s %s\n' "agent" "installed" "config" "version/path"
  while IFS= read -r provider; do
    binary_name="$(provider_binary_name "$provider")"
    config_dir="$(provider_config_dir "$provider")"
    installed="no"
    version_line="missing"
    config_state="missing"

    if command_exists "$binary_name"; then
      installed="yes"
      version_line="$(command_version_line "$binary_name")"
      if [[ -z "$version_line" ]]; then
        version_line="$(command -v "$binary_name")"
      fi
    fi

    if [[ -e "$config_dir" ]]; then
      config_state="present"
    fi

    printf '%-14s %-10s %-12s %s\n' "$provider" "$installed" "$config_state" "$version_line"
  done < <(provider_names)
}

doctor_all() {
  local provider
  local first=1

  while IFS= read -r provider; do
    if ((first == 0)); then
      echo ""
    fi
    first=0
    printf '=== %s ===\n' "$provider"
    run_provider "$provider" doctor
  done < <(provider_names)
}

main() {
  local command="${1:-menu}"

  case "$command" in
    menu)
      run_menu
      ;;
    list)
      print_provider_list
      ;;
    status)
      show_status
      ;;
    doctor-all)
      doctor_all
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      run_provider "$command" "${@:2}"
      ;;
  esac
}

main "$@"
