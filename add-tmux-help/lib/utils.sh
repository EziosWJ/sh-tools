#!/usr/bin/env bash
# 工具函数模块
# 提供颜色输出、依赖检查、配置处理等基础功能

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 带颜色的输出函数
info() {
  printf "${BLUE}[INFO]${NC} %s\n" "$*"
}

success() {
  printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"
}

warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2
}

error() {
  printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
}

debug() {
  if [[ "${TMUX_HELPER_DEBUG:-0}" == "1" ]]; then
    printf "${PURPLE}[DEBUG]${NC} %s\n" "$*" >&2
  fi
}

# 检查命令是否存在
check_command() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    debug "命令 $cmd 可用"
    return 0
  else
    debug "命令 $cmd 不可用"
    return 1
  fi
}

# 检查是否在tmux中运行
in_tmux() {
  [[ -n "${TMUX:-}" ]]
}

# 获取tmux版本
get_tmux_version() {
  if in_tmux; then
    tmux -V | cut -d' ' -f2
  else
    echo "unknown"
  fi
}

# 比较版本号
version_compare() {
  local version1="$1"
  local version2="$2"
  
  # 移除可能的字母后缀
  version1="${version1%%[a-z]*}"
  version2="${version2%%[a-z]*}"
  
  if [[ "$version1" == "$version2" ]]; then
    return 0
  fi
  
  local IFS=.
  local i ver1=($version1) ver2=($version2)
  
  for ((i=0; i<${#ver1[@]} || i<${#ver2[@]}; i++)); do
    if [[ ${ver1[i]:-0} -gt ${ver2[i]:-0} ]]; then
      return 1
    fi
    if [[ ${ver1[i]:-0} -lt ${ver2[i]:-0} ]]; then
      return 2
    fi
  done
  
  return 0
}

# 配置文件处理
load_config() {
  local config_file="${1:-$HOME/.config/tmux-helper/config}"
  
  if [[ -f "$config_file" ]]; then
    debug "加载配置文件: $config_file"
    source "$config_file"
  else
    debug "配置文件不存在: $config_file，使用默认值"
  fi
  
  # 设置默认值
  export TMUX_HELPER_SCAN_DIRS="${TMUX_HELPER_SCAN_DIRS:-$HOME/projects,$HOME/work,$HOME/code}"
  export TMUX_HELPER_SESSION_DIR="${TMUX_HELPER_SESSION_DIR:-$HOME/.config/tmux-helper/sessions}"
  export TMUX_HELPER_TEMPLATE_FILE="${TMUX_HELPER_TEMPLATE_FILE:-$HOME/.config/tmux-helper/templates.conf}"
  export TMUX_HELPER_DEFAULT_EDITOR="${TMUX_HELPER_DEFAULT_EDITOR:-vim}"
  export TMUX_HELPER_SELECTOR="${TMUX_HELPER_SELECTOR:-fzf}"
}

# 确保目录存在
ensure_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    debug "创建目录: $dir"
  fi
}

# 解析目录路径（展开~等）
resolve_path() {
  local path="$1"
  echo "${path/#\~/$HOME}"
}

# 交互式选择器
select_option() {
  local prompt="$1"
  shift
  local options=("$@")
  
  if [[ "$TMUX_HELPER_SELECTOR" == "fzf" ]] && check_command fzf; then
    printf '%s\n' "${options[@]}" | fzf --prompt="$prompt" --height=40% --reverse
  else
    # 回退到select菜单
    echo "$prompt" >&2
    local i=1
    for opt in "${options[@]}"; do
      echo "  $i) $opt" >&2
      ((i++))
    done
    
    local choice
    printf "请选择编号: " >&2
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
      echo "${options[$choice]}"
    else
      echo ""
    fi
  fi
}

# 搜索功能
search_in_list() {
  local keyword="$1"
  shift
  local list=("$@")
  
  if [[ "$TMUX_HELPER_SELECTOR" == "fzf" ]] && check_command fzf; then
    printf '%s\n' "${list[@]}" | fzf --filter="$keyword" --height=40% --reverse
  else
    # 简单grep搜索
    printf '%s\n' "${list[@]}" | grep -i "$keyword" || true
  fi
}

# JSON处理（如果jq可用）
json_get() {
  local json="$1"
  local key="$2"
  
  if check_command jq; then
    echo "$json" | jq -r ".$key // empty"
  else
    # 简单的JSON解析（仅支持基本格式）
    echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | cut -d'"' -f4
  fi
}

# 生成JSON
json_create() {
  local name="$1"
  local created="$2"
  
  if check_command jq; then
    jq -n --arg name "$name" --arg created "$created" '{
      name: $name,
      created: $created,
      windows: []
    }'
  else
    cat <<EOF
{
  "name": "$name",
  "created": "$created",
  "windows": []
}
EOF
  fi
}

# 验证会话名称
validate_session_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "无效的会话名称: $name"
    echo "会话名称只能包含字母、数字、下划线和连字符"
    return 1
  fi
  return 0
}

# 显示帮助信息
show_help() {
  local script_name="$1"
  local description="$2"
  shift 2
  
  echo "用法: $script_name [选项] [参数]"
  echo ""
  echo "描述: $description"
  echo ""
  echo "选项:"
  for opt in "$@"; do
    echo "  $opt"
  done
  echo ""
  echo "示例:"
  echo "  $script_name --help"
}