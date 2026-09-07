#!/usr/bin/env bash

tool_registry_names() {
  printf '%s\n' \
    "init-Linux" \
    "add-tmux-help" \
    "agents" \
    "skills" \
    "mihomo"
}

tool_registry_description() {
  local tool="$1"

  case "$tool" in
    init-Linux)
      printf '%s\n' "Debian 系 Linux 开发环境初始化脚本（含 WSL 增强）"
      ;;
    add-tmux-help)
      printf '%s\n' "tmux 会话菜单与快捷键帮助"
      ;;
    agents)
      printf '%s\n' "AI agent 工具安装入口，支持 Codex、Claude Code、OpenCode、Hermes、Pi Agent"
      ;;
    skills)
      printf '%s\n' "skills 安装入口，二级选择具体 provider"
      ;;
    mihomo)
      printf '%s\n' "Mihomo TUN 配置、systemd 服务与运行管理"
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
    agents)
      printf '%s\n' "agents/agents.sh"
      ;;
    skills)
      printf '%s\n' "skills/skills.sh"
      ;;
    mihomo)
      printf '%s\n' "mihomo/mihomo.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

tool_registry_remote_entry() {
  tool_registry_local_entry "$1"
}
