#!/usr/bin/env bash

tool_registry_names() {
  printf '%s\n' \
    "init-Linux" \
    "add-tmux-help" \
    "proxyctl" \
    "install-karpathy-skills" \
    "skills"
}

tool_registry_description() {
  local tool="$1"

  case "$tool" in
    init-Linux)
      printf '%s\n' "Linux/WSL 开发环境初始化脚本"
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
    skills)
      printf '%s\n' "skills 安装入口，二级选择具体 provider"
      ;;
    *)
      return 1
      ;;
  esac
}

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
    skills)
      printf '%s\n' "skills/skills.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

tool_registry_remote_entry() {
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
    skills)
      printf '%s\n' "skills/skills.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

tool_registry_menu_command_count() {
  local tool="$1"

  case "$tool" in
    proxyctl)
      printf '%s\n' "11"
      ;;
    init-Linux|add-tmux-help|install-karpathy-skills|skills)
      printf '%s\n' "0"
      ;;
    *)
      return 1
      ;;
  esac
}

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
