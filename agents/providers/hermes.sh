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
  require_commands curl bash || return 1
  warn_if_not_tty
  info "将执行 Hermes Agent 官方安装脚本："
  print_command bash -lc 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
  confirm "是否继续安装 Hermes Agent？" || return 0
  bash -lc 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
}

doctor() {
  info "Hermes Agent 状态："
  report_binary_status "hermes" "hermes" || true
  report_binary_status "curl" "curl" || true
  report_env_status "OPENAI_API_KEY" "OPENAI_API_KEY"
  report_env_status "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY"
  report_path_status "config dir" "$HOME/.hermes"
}

remove_info() {
  info "Hermes Agent 卸载建议："
  echo "  Hermes 官方安装一般落在 ~/.hermes。"
  echo "  如需清理用户数据，可自行检查："
  print_command rm -rf "$HOME/.hermes"
}

update_latest() {
  if command_exists hermes; then
    warn_if_not_tty
    info "将执行 Hermes 内置更新命令："
    print_command hermes update
    confirm "是否继续更新 Hermes Agent？" || return 0
    hermes update
    return 0
  fi

  warn "未检测到 hermes，改为执行官方安装脚本。"
  run_method
}

show_menu() {
  echo "请选择 Hermes Agent 操作："
  echo ""
  echo "1) install/curl - 官方安装脚本"
  echo "2) doctor - 检查安装状态"
  echo "3) update - 优先使用 hermes update"
  echo "4) remove-info - 查看卸载建议"
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
        1) run_method ;;
        2) doctor ;;
        3) update_latest ;;
        4) remove_info ;;
        0) return 0 ;;
        *) error "输入无效。"; return 1 ;;
      esac
      ;;
    curl)
      run_method
      ;;
    list)
      printf '%s\n' "curl"
      ;;
    doctor)
      doctor
      ;;
    remove-info)
      remove_info
      ;;
    update)
      update_latest
      ;;
    -h|--help|help)
      printf '用法：\n  bash agents/providers/hermes.sh [curl|doctor|update|remove-info]\n'
      ;;
    *)
      error "Hermes 仅支持 curl 安装方式。"
      return 1
      ;;
  esac
}

main "$@"
