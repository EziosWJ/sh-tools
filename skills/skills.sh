#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
RUNTIME_DIR="${SH_TOOLS_SKILLS_RUNTIME_DIR:-$HOME/.local/share/sh-tools/skills}"

provider_names() {
  printf '%s\n' \
    "agents-template" \
    "karpathy" \
    "mattpocock"
}

provider_description() {
  local provider="$1"

  case "$provider" in
    agents-template)
      printf '%s\n' "初始化中文 AGENTS.md 与引用它的 CLAUDE.md"
      ;;
    karpathy)
      printf '%s\n' "下载 Karpathy CLAUDE.md 并创建 AGENTS.md 软链接"
      ;;
    mattpocock)
      printf '%s\n' "通过 npx 启动 mattpocock/skills 的交互式安装"
      ;;
    *)
      return 1
      ;;
  esac
}

provider_local_entry() {
  local provider="$1"

  case "$provider" in
    agents-template)
      printf '%s\n' "providers/agents-template.sh"
      ;;
    karpathy)
      printf '%s\n' "providers/karpathy.sh"
      ;;
    mattpocock)
      printf '%s\n' "providers/mattpocock.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

provider_remote_entry() {
  provider_local_entry "$1"
}

usage() {
  echo "用法："
  echo "  bash skills/skills.sh"
  echo "  bash skills/skills.sh list"

  local provider
  while IFS= read -r provider; do
    echo "  bash skills/skills.sh $provider"
  done < <(provider_names)
}

download_remote_file() {
  local remote_path="$1"
  local target_file="$2"

  mkdir -p "$(dirname "$target_file")" || return 1
  local temporary
  temporary="$(mktemp "${target_file}.XXXXXX")" || return 1
  if ! curl -fsSL -o "$temporary" "$REPO_RAW_BASE/skills/$remote_path"; then
    rm -f -- "$temporary"
    return 1
  fi
  mv -- "$temporary" "$target_file"
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
  download_remote_file "$entry" "$runtime_path" || return 1
  printf '%s\n' "$runtime_path"
}

run_provider() {
  local provider="$1"
  shift || true
  local script_path

  script_path="$(provider_script_path "$provider")" || {
    printf '无法加载 provider（名称无效或下载失败）：%s\n\n' "$provider" >&2
    usage
    return 1
  }

  bash "$script_path" "$@"
}

print_provider_list() {
  provider_names
}

show_menu() {
  local index=1
  local provider
  local description

  echo "请选择 skills provider："
  echo ""

  while IFS= read -r provider; do
    description="$(provider_description "$provider")"
    printf '%s) %s - %s\n' "$index" "$provider" "$description"
    index=$((index + 1))
  done < <(provider_names)

  echo "0) 返回上一级"
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
  local selected provider
  while true; do
    show_menu
    read -r -p "请输入选项编号: " selected || return 0
    case "$selected" in
      0) return 0 ;;
    esac
    provider="$(pick_provider_by_index "$selected")" || {
      printf '输入无效。\n' >&2
      continue
    }
    run_provider "$provider" || printf '操作失败，请检查上方错误后重试。\n' >&2
  done
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
    -h|--help|help)
      usage
      ;;
    *)
      run_provider "$command" "${@:2}"
      ;;
  esac
}

main "$@"
