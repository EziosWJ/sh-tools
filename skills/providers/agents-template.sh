#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
AGENTS_TEMP=""
CLAUDE_TEMP=""
TEMPLATE_TEMP=""
TEMPLATE_PATH=""

usage() {
  cat <<'EOF'
用法：
  bash agents-template.sh [--force] [项目目录]

在项目目录创建：
  AGENTS.md   中文通用 agent 规则
  CLAUDE.md   内容为 @AGENTS.md，供 Claude Code 引用

默认使用当前目录；目标文件已存在时拒绝覆盖，传入 --force 才会覆盖。
EOF
}

error() {
  printf '错误：%s\n' "$*" >&2
}

target_has_file() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]]
}

resolve_template() {
  local local_template="$SCRIPT_DIR/../AGENTS-example.md"

  if [[ -f "$local_template" ]]; then
    TEMPLATE_PATH="$local_template"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    error "远程执行时需要 curl 下载 AGENTS 模板。"
    return 1
  fi

  TEMPLATE_TEMP="$(mktemp "${TMPDIR:-/tmp}/agents-template.XXXXXX")"
  curl -fsSL "$REPO_RAW_BASE/skills/AGENTS-example.md" -o "$TEMPLATE_TEMP"
  TEMPLATE_PATH="$TEMPLATE_TEMP"
}

main() {
  local force=0
  local target_dir=""
  local template_path
  local name

  while (( $# > 0 )); do
    case "$1" in
      --force)
        force=1
        ;;
      -h|--help|help)
        usage
        return 0
        ;;
      --)
        shift
        if (( $# > 1 )); then
          error "最多只能指定一个项目目录。"
          return 1
        fi
        target_dir="${1:-$PWD}"
        break
        ;;
      -*)
        error "未知选项：$1"
        usage >&2
        return 1
        ;;
      *)
        if [[ -n "$target_dir" ]]; then
          error "最多只能指定一个项目目录。"
          return 1
        fi
        target_dir="$1"
        ;;
    esac
    shift
  done

  target_dir="${target_dir:-$PWD}"
  if [[ ! -d "$target_dir" ]]; then
    error "项目目录不存在：$target_dir"
    return 1
  fi
  target_dir="$(cd "$target_dir" && pwd -P)"

  if (( ! force )); then
    for name in AGENTS.md CLAUDE.md; do
      if target_has_file "$target_dir/$name"; then
        error "$target_dir/$name 已存在；如确认覆盖，请添加 --force。"
        return 1
      fi
    done
  fi

  trap 'rm -f -- "${AGENTS_TEMP:-}" "${CLAUDE_TEMP:-}" "${TEMPLATE_TEMP:-}"' EXIT
  resolve_template
  template_path="$TEMPLATE_PATH"

  AGENTS_TEMP="$(mktemp "$target_dir/.AGENTS.md.XXXXXX")"
  CLAUDE_TEMP="$(mktemp "$target_dir/.CLAUDE.md.XXXXXX")"
  cp "$template_path" "$AGENTS_TEMP"
  printf '%s\n' '@AGENTS.md' > "$CLAUDE_TEMP"
  chmod 644 "$AGENTS_TEMP" "$CLAUDE_TEMP"

  mv -f "$AGENTS_TEMP" "$target_dir/AGENTS.md"
  AGENTS_TEMP=""
  mv -f "$CLAUDE_TEMP" "$target_dir/CLAUDE.md"
  CLAUDE_TEMP=""

  printf '已初始化项目规则：%s\n' "$target_dir"
  printf '  AGENTS.md：中文通用 agent 规则\n'
  printf '  CLAUDE.md：@AGENTS.md\n'
}

main "$@"
