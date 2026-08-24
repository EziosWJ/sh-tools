#!/usr/bin/env bash

tool_registry_names() {
  printf '%s\n' \
    "init-Linux" \
    "add-tmux-help" \
    "install-karpathy-skills" \
    "agents" \
    "skills"
}

tool_registry_description() {
  local tool="$1"

  case "$tool" in
    init-Linux)
      printf '%s\n' "Debian 系 Linux 开发环境初始化脚本（含 WSL 增强）"
      ;;
    add-tmux-help)
      printf '%s\n' "向 shell 配置添加 tmux 快捷键帮助函数"
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

tool_registry_local_entry() {
  local tool="$1"

  case "$tool" in
    init-Linux)
      printf '%s\n' "init-Linux/init-linux.sh"
      ;;
    add-tmux-help)
      printf '%s\n' "add-tmux-help/add-tmux-help.sh"
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

tool_registry_remote_entry() {
  local tool="$1"

  case "$tool" in
    init-Linux)
      printf '%s\n' "init-Linux/init-linux.sh"
      ;;
    add-tmux-help)
      printf '%s\n' "add-tmux-help/add-tmux-help.sh"
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

tool_registry_menu_command_count() {
  local tool="$1"

  case "$tool" in
    init-Linux|add-tmux-help|install-karpathy-skills|agents|skills)
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
    *)
      return 1
      ;;
  esac
}
