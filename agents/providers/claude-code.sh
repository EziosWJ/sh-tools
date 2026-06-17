#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
RUNTIME_DIR="${SH_TOOLS_AGENTS_RUNTIME_DIR:-$HOME/.local/share/sh-tools/agents}"
if [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/../lib/common.sh"
else
  mkdir -p "$RUNTIME_DIR/lib"
  curl -fsSL -o "$RUNTIME_DIR/lib/common.sh" "$REPO_RAW_BASE/agents/lib/common.sh"
  # shellcheck disable=SC1090
  source "$RUNTIME_DIR/lib/common.sh"
fi

run_method() {
  local action="$1"
  local method="$2"
  local action_label="安装"

  if [[ "$action" == "update" ]]; then
    action_label="更新"
  fi

  case "$method" in
    curl)
      require_commands curl bash || return 1
      warn_if_not_tty
      if [[ "$action" == "update" ]]; then
        info "将通过官方安装脚本更新 Claude Code 到最新版本："
      else
        info "将执行 Claude Code 官方安装脚本："
      fi
      print_command bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
      confirm "是否继续${action_label} Claude Code？" || return 0
      bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
      ;;
    npm)
      require_commands npm || return 1
      warn "官方 README 已标注 npm 安装方式为 deprecated。"
      if [[ "$action" == "update" ]]; then
        info "将通过 npm 更新 Claude Code 到最新版本："
      else
        info "将通过 npm 安装 Claude Code："
      fi
      print_command npm install -g @anthropic-ai/claude-code
      confirm "是否继续使用已弃用的 npm 方式${action_label} Claude Code？" || return 0
      npm install -g @anthropic-ai/claude-code
      ;;
    *)
      error "未知安装方式：$method"
      return 1
      ;;
  esac
}

doctor() {
  info "Claude Code 状态："
  report_binary_status "claude" "claude" || true
  report_binary_status "npm" "npm" || true
  report_binary_status "curl" "curl" || true
  report_env_status "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY"
  report_path_status "config dir" "$HOME/.claude"
}

remove_info() {
  info "Claude Code 卸载建议："
  echo "  npm 安装卸载："
  print_command npm uninstall -g @anthropic-ai/claude-code
  echo "  curl 安装通常需参考官方 setup 文档处理安装落点。"
  echo "  如需清理用户数据，可自行检查："
  print_command rm -rf "$HOME/.claude"
}

show_menu() {
  echo "请选择 Claude Code 操作："
  echo ""
  echo "1) install/curl - 官方安装脚本（推荐）"
  echo "2) install/npm - 全局安装（官方已标记为 deprecated）"
  echo "3) doctor - 检查安装状态"
  echo "4) update/curl - 用官方脚本更新"
  echo "5) update/npm - 用 npm 更新（deprecated）"
  echo "6) remove-info - 查看卸载建议"
  echo "0) 退出"
}

main() {
  local method="${1:-menu}"
  local choice

  case "$method" in
    menu)
      show_menu
      echo ""
      read -r -p "请输入选项编号: " choice || return 0
      case "$choice" in
        1) run_method install curl ;;
        2) run_method install npm ;;
        3) doctor ;;
        4) run_method update curl ;;
        5) run_method update npm ;;
        6) remove_info ;;
        0) return 0 ;;
        *) error "输入无效。"; return 1 ;;
      esac
      ;;
    list)
      printf '%s\n' "curl" "npm"
      ;;
    doctor)
      doctor
      ;;
    remove-info)
      remove_info
      ;;
    curl|npm)
      run_method install "$method"
      ;;
    update-curl)
      run_method update curl
      ;;
    update-npm)
      run_method update npm
      ;;
    -h|--help|help)
      printf '用法：\n  bash agents/providers/claude-code.sh [curl|npm|doctor|update-curl|update-npm|remove-info]\n'
      ;;
    *)
      error "未知参数：$method"
      return 1
      ;;
  esac
}

main "$@"
