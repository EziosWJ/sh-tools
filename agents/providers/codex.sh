#!/usr/bin/env bash
set -Eeuo pipefail

# 进程替换输入是一次性管道；先保存完整入口，供菜单重复启动子操作。
if [[ "$0" == /dev/fd/* || "$0" == /proc/self/fd/* ]]; then
  menu_script="$(mktemp)"
  trap 'rm -f -- "$menu_script"' EXIT
  curl -fsSL "${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}/agents/providers/codex.sh" -o "$menu_script"
  bash "$menu_script" "$@"
  exit $?
fi

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

method_names() {
  printf '%s\n' "curl" "npm"
}

method_description() {
  case "$1" in
    curl) printf '%s\n' "官方安装脚本：curl -fsSL https://chatgpt.com/codex/install.sh | sh" ;;
    npm) printf '%s\n' "npm 全局安装：npm install -g @openai/codex" ;;
    *) return 1 ;;
  esac
}

run_method() {
  local action="$1"
  local method="$2"
  local action_label="安装"

  if [[ "$action" == "update" ]]; then
    action_label="更新"
  fi

  case "$method" in
    curl)
      require_commands curl sh || return 1
      warn_if_not_tty
      if [[ "$action" == "update" ]]; then
        info "将通过官方安装脚本更新 Codex 到最新版本："
      else
        info "将执行 Codex 官方安装脚本："
      fi
      print_command bash -lc 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
      confirm "是否继续${action_label} Codex？" || return 0
      bash -lc 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
      ;;
    npm)
      require_commands npm || return 1
      if [[ "$action" == "update" ]]; then
        info "将通过 npm 更新 Codex 到最新版本："
      else
        info "将通过 npm 安装 Codex："
      fi
      print_command npm install -g @openai/codex
      confirm "是否继续${action_label} Codex？" || return 0
      npm install -g @openai/codex
      ;;
    *)
      error "未知安装方式：$method"
      return 1
      ;;
  esac
}

doctor() {
  info "Codex 状态："
  report_binary_status "codex" "codex" || true
  report_binary_status "npm" "npm" || true
  report_binary_status "curl" "curl" || true
  report_env_status "OPENAI_API_KEY" "OPENAI_API_KEY"
  report_path_status "config dir" "$HOME/.codex"
}

remove_info() {
  info "Codex 卸载建议："
  echo "  npm 安装卸载："
  print_command npm uninstall -g @openai/codex
  echo "  如需清理用户数据，可自行检查："
  print_command rm -rf "$HOME/.codex"
}

show_menu() {
  echo "请选择 Codex 操作："
  echo ""
  echo "1) install/curl - 官方安装脚本"
  echo "2) install/npm - 全局安装"
  echo "3) doctor - 检查安装状态"
  echo "4) update/curl - 用官方脚本更新"
  echo "5) update/npm - 用 npm 更新"
  echo "6) remove-info - 查看卸载建议"
  echo "0) 返回上一级"
}

main() {
  local method="${1:-menu}"
  local choice

  case "$method" in
    menu)
      while true; do
        show_menu
        read -r -p "请输入选项编号: " choice || return 0
        case "$choice" in
          1) method="curl" ;;
          2) method="npm" ;;
          3) method="doctor" ;;
          4) method="update-curl" ;;
          5) method="update-npm" ;;
          6) method="remove-info" ;;
          0) return 0 ;;
          *) error "输入无效。"; continue ;;
        esac
        bash "$0" "$method" || error "操作失败，请检查上方错误后重试。"
      done
      ;;
    list)
      method_names
      ;;
    doctor)
      doctor
      ;;
    remove-info)
      remove_info
      ;;
    update)
      error "请指定更新方式：curl 或 npm"
      return 1
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
      printf '用法：\n  bash agents/providers/codex.sh [curl|npm|doctor|update-curl|update-npm|remove-info]\n'
      ;;
    *)
      error "未知参数：$method"
      return 1
      ;;
  esac
}

main "$@"
