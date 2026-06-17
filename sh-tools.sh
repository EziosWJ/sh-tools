#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"

usage() {
  cat <<'EOF'
用法：
  bash sh-tools.sh
  bash sh-tools.sh menu
  bash sh-tools.sh list
  bash sh-tools.sh init-Linux [args...]
  bash sh-tools.sh add-tmux-help [args...]
  bash sh-tools.sh proxyctl [args...]
  bash sh-tools.sh install-karpathy-skills [args...]
EOF
}

has_local_tool() {
  local tool="$1"

  case "$tool" in
    init-Linux)
      [[ -f "$SCRIPT_DIR/init-Linux/init-linux.sh" ]]
      ;;
    add-tmux-help)
      [[ -f "$SCRIPT_DIR/add-tmux-help/add-tmux-help.sh" ]]
      ;;
    proxyctl)
      [[ -f "$SCRIPT_DIR/proxyctl/proxyctl.sh" ]]
      ;;
    install-karpathy-skills)
      [[ -f "$SCRIPT_DIR/install-karpathy-skills/install-karpathy-skills.sh" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

run_remote_bash_script() {
  local url="$1"
  shift || true
  bash <(curl -fsSL "$url") "$@"
}

run_remote_tool() {
  local tool="$1"
  shift || true

  case "$tool" in
    init-Linux)
      run_remote_bash_script "$REPO_RAW_BASE/init-Linux/init-linux.sh" "$@"
      ;;
    add-tmux-help)
      run_remote_bash_script "$REPO_RAW_BASE/add-tmux-help/add-tmux-help.sh" "$@"
      ;;
    proxyctl)
      if (($# == 0)); then
        run_remote_bash_script "$REPO_RAW_BASE/proxyctl/proxyctl.sh"
      else
        bash <(curl -fsSL "$REPO_RAW_BASE/proxyctl/proxyctl.sh") "$@"
      fi
      ;;
    install-karpathy-skills)
      run_remote_bash_script "$REPO_RAW_BASE/install-karpathy-skills/install-karpathy-skills.sh" "$@"
      ;;
    *)
      printf '未知工具：%s\n\n' "$tool" >&2
      usage
      return 1
      ;;
  esac
}

run_tool() {
  local tool="$1"
  shift || true

  if has_local_tool "$tool"; then
    case "$tool" in
      init-Linux)
        bash "$SCRIPT_DIR/init-Linux/init-linux.sh" "$@"
        ;;
      add-tmux-help)
        bash "$SCRIPT_DIR/add-tmux-help/add-tmux-help.sh" "$@"
        ;;
      proxyctl)
        bash "$SCRIPT_DIR/proxyctl/proxyctl.sh" "$@"
        ;;
      install-karpathy-skills)
        bash "$SCRIPT_DIR/install-karpathy-skills/install-karpathy-skills.sh" "$@"
        ;;
    esac
    return 0
  fi

  run_remote_tool "$tool" "$@"
}

show_menu() {
  cat <<'EOF'
请选择工具：

1) init-Linux
2) add-tmux-help
3) proxyctl
4) install-karpathy-skills
5) 列出工具
0) 退出
EOF
}

prompt_proxyctl_command() {
  local command

  cat <<'EOF'
请选择 proxyctl 命令：

1) on
2) off
3) apt-on
4) apt-off
5) docker-on
6) docker-off
7) docker-status
8) pip-on
9) pip-off
10) pip-status
11) status
0) 返回
EOF

  read -r -p "请输入选项编号: " command || return 0

  case "$command" in
    1) run_tool proxyctl on ;;
    2) run_tool proxyctl off ;;
    3) run_tool proxyctl apt-on ;;
    4) run_tool proxyctl apt-off ;;
    5) run_tool proxyctl docker-on ;;
    6) run_tool proxyctl docker-off ;;
    7) run_tool proxyctl docker-status ;;
    8) run_tool proxyctl pip-on ;;
    9) run_tool proxyctl pip-off ;;
    10) run_tool proxyctl pip-status ;;
    11) run_tool proxyctl status ;;
    0) return 0 ;;
    *) printf '无效选项，请输入 0-11。\n' >&2; return 1 ;;
  esac
}

interactive_menu() {
  local choice

  while true; do
    printf '\n'
    show_menu
    read -r -p "请输入选项编号: " choice || return 0

    case "$choice" in
      1) run_tool init-Linux ;;
      2) run_tool add-tmux-help ;;
      3) prompt_proxyctl_command ;;
      4) run_tool install-karpathy-skills ;;
      5) printf 'init-Linux\nadd-tmux-help\nproxyctl\ninstall-karpathy-skills\n' ;;
      0) return 0 ;;
      *) printf '无效选项，请输入 0-5。\n' >&2 ;;
    esac
  done
}

main() {
  local command="${1:-menu}"

  case "$command" in
    menu)
      interactive_menu
      ;;
    list)
      printf 'init-Linux\nadd-tmux-help\nproxyctl\ninstall-karpathy-skills\n'
      ;;
    -h|--help|help)
      usage
      ;;
    init-Linux|add-tmux-help|proxyctl|install-karpathy-skills)
      shift
      run_tool "$command" "$@"
      ;;
    *)
      printf '未知命令：%s\n\n' "$command" >&2
      usage
      return 1
      ;;
  esac
}

main "$@"
