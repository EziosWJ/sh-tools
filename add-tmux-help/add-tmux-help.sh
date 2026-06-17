#!/usr/bin/env bash
set -Eeuo pipefail

marker_start() {
  local func_name="$1"
  printf '# >>> %s >>>\n' "$func_name"
}

marker_end() {
  local func_name="$1"
  printf '# <<< %s <<<\n' "$func_name"
}
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
RUNTIME_DIR="${ADD_TMUX_HELP_RUNTIME_DIR:-$HOME/.local/share/sh-tools/add-tmux-help}"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_DIR="$SCRIPT_DIR"

bootstrap_info() {
  printf '[INFO] %s\n' "$*"
}

bootstrap_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

bootstrap_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

bootstrap_runtime_assets() {
  local target_dir="$1"
  local files=(
    "lib/utils.sh"
    "lib/tmux-help.sh"
    "lib/tmux-session.sh"
    "tmux.conf.example"
  )
  local file

  if ! command -v curl >/dev/null 2>&1; then
    bootstrap_error "远程执行 add-tmux-help 需要 curl 下载运行时文件。"
    return 1
  fi

  mkdir -p "$target_dir/lib"
  for file in "${files[@]}"; do
    bootstrap_info "下载运行时文件: $file"
    curl -fsSL "$REPO_RAW_BASE/add-tmux-help/$file" -o "$target_dir/$file" || {
      bootstrap_error "下载失败: $REPO_RAW_BASE/add-tmux-help/$file"
      return 1
    }
  done
}

if [[ ! -f "$ASSET_DIR/lib/utils.sh" ]]; then
  ASSET_DIR="$RUNTIME_DIR"
  bootstrap_runtime_assets "$ASSET_DIR"
fi

# 加载工具函数
source "$ASSET_DIR/lib/utils.sh"
if [[ -f "$SCRIPT_DIR/../lib/shell-integration.sh" ]]; then
  source "$SCRIPT_DIR/../lib/shell-integration.sh"
fi

if ! declare -F shell_rc_files >/dev/null 2>&1; then
  shell_rc_files() {
    local rc_file
    local rc_files=(
      "$HOME/.bashrc"
      "$HOME/.zshrc"
    )

    for rc_file in "${rc_files[@]}"; do
      if [[ -f "$rc_file" ]]; then
        printf '%s\n' "$rc_file"
      fi
    done
  }
fi

if ! declare -F shell_replace_marked_block >/dev/null 2>&1; then
  shell_replace_marked_block() {
    local file="$1"
    local marker_start="$2"
    local marker_end="$3"
    local block="$4"

    if [[ ! -f "$file" ]]; then
      warn "$file 不存在，已跳过写入。"
      return 1
    fi

    if grep -qF "$marker_start" "$file"; then
      sed -i "/$marker_start/,/$marker_end/d" "$file"
    fi

    printf '\n%s\n' "$block" >> "$file"
  }
fi

if ! declare -F shell_remove_marked_block >/dev/null 2>&1; then
  shell_remove_marked_block() {
    local file="$1"
    local marker_start="$2"
    local marker_end="$3"

    if [[ ! -f "$file" ]]; then
      return 1
    fi

    if grep -qF "$marker_start" "$file"; then
      sed -i "/$marker_start/,/$marker_end/d" "$file"
    fi
  }
fi

# 检查依赖
check_dependencies() {
  local required_deps=("bash" "tmux")
  local optional_deps=("fzf" "jq")
  local missing_required=()
  local missing_optional=()
  
  for dep in "${required_deps[@]}"; do
    if ! check_command "$dep"; then
      missing_required+=("$dep")
    fi
  done
  
  for dep in "${optional_deps[@]}"; do
    if ! check_command "$dep"; then
      missing_optional+=("$dep")
    fi
  done
  
  if [[ ${#missing_required[@]} -gt 0 ]]; then
    error "缺少必要依赖: ${missing_required[*]}"
    echo "请安装这些依赖后重试"
    return 1
  fi
  
  if [[ ${#missing_optional[@]} -gt 0 ]]; then
    warn "缺少可选依赖: ${missing_optional[*]}"
    echo "某些功能可能受限，但基本功能可用"
  fi
  
  return 0
}

# 创建配置目录
create_config_dirs() {
  local config_dir="$HOME/.config/tmux-helper"
  local session_dir="$config_dir/sessions"
  local template_file="$config_dir/templates.conf"
  
  ensure_directory "$config_dir"
  ensure_directory "$session_dir"
  
  # 创建默认模板文件（如果不存在）
  if [[ ! -f "$template_file" ]]; then
    cat > "$template_file" <<EOF
# tmux-helper 模板配置
# 格式: 模板名称|工作目录|启动命令
web-project|~/projects/webapp|npm run dev
python-api|~/projects/api|python manage.py runserver
node-server|~/projects/node-app|node server.js
EOF
    info "创建默认模板文件: $template_file"
  fi
  
  # 创建默认配置文件（如果不存在）
  local config_file="$config_dir/config"
  if [[ ! -f "$config_file" ]]; then
    cp "$ASSET_DIR/tmux.conf.example" "$config_file"
    info "创建默认配置文件: $config_file"
  fi
}

# 生成函数定义
generate_function_def() {
  local func_name="$1"
  local func_file="$2"
  local block_marker_start
  local block_marker_end

  block_marker_start="$(marker_start "$func_name")"
  block_marker_end="$(marker_end "$func_name")"
  
  cat <<EOF
$block_marker_start
# tmux-helper 函数定义
# 自动安装于 $(date -Iseconds)

# 加载工具函数
if [[ -f "$ASSET_DIR/lib/utils.sh" ]]; then
  source "$ASSET_DIR/lib/utils.sh"
fi

# 加载 $func_name 模块
if [[ -f "$func_file" ]]; then
  source "$func_file"
fi

# $func_name 主函数
$func_name() {
  ${func_name//[-]/_}_main "\$@"
}
$block_marker_end
EOF
}

# 添加到rc文件
add_to_rc() {
  local rc_file="$1"
  local func_name="$2"
  local func_file="$3"
  local block_marker_start
  local block_marker_end
  block_marker_start="$(marker_start "$func_name")"
  block_marker_end="$(marker_end "$func_name")"
  
  if [[ ! -f "$rc_file" ]]; then
    warn "$rc_file 不存在，跳过"
    return
  fi
  
  if grep -qF "$block_marker_start" "$rc_file"; then
    info "$rc_file 中已移除旧版 $func_name"
  fi
  
  local function_def
  function_def="$(generate_function_def "$func_name" "$func_file")"
  shell_replace_marked_block "$rc_file" "$block_marker_start" "$block_marker_end" "$function_def"
  success "已添加 $func_name 到 $rc_file"
}

# 安装主函数
install_main() {
  info "开始安装 tmux-helper..."
  
  # 检查依赖
  if ! check_dependencies; then
    return 1
  fi
  
  # 创建配置目录
  create_config_dirs
  
  # 安装各个模块
  local modules=(
    "tmux-help:$ASSET_DIR/lib/tmux-help.sh"
    "tmux-session:$ASSET_DIR/lib/tmux-session.sh"
  )
  
  for module_info in "${modules[@]}"; do
    local func_name="${module_info%%:*}"
    local func_file="${module_info##*:}"
    
    if [[ ! -f "$func_file" ]]; then
      error "模块文件不存在: $func_file"
      return 1
    fi
    
    while IFS= read -r rc_file; do
      add_to_rc "$rc_file" "$func_name" "$func_file"
    done < <(shell_rc_files)
  done
  
  # 创建符号链接（可选）
  local bin_dir="$HOME/.local/bin"
  if [[ -d "$bin_dir" ]]; then
    for module_info in "${modules[@]}"; do
      local func_name="${module_info%%:*}"
      local link_name="$bin_dir/$func_name"
      # 将连字符转换为下划线作为函数名
      local main_func="${func_name//[-]/_}_main"
      
      if [[ ! -L "$link_name" ]]; then
        # 创建包装脚本
        cat > "$link_name" <<WRAPPER
#!/usr/bin/env bash
source "$ASSET_DIR/lib/utils.sh"
source "${module_info##*:}"
$main_func "\$@"
WRAPPER
        chmod +x "$link_name"
        info "创建符号链接: $link_name"
      fi
    done
  fi
  
  success "安装完成！"
  echo ""
  echo "请执行以下命令使配置生效:"
  echo "  source ~/.bashrc   # bash"
  echo "  source ~/.zshrc    # zsh"
  echo ""
  echo "可用命令:"
  echo "  tmux-help              # 显示所有快捷键帮助"
  echo "  tmux-help session      # 查看会话管理帮助"
  echo "  tmux-help -i           # 交互模式"
  echo "  tmux-session           # 交互式选择/创建会话"
  echo "  tmux-session <名称>    # 切换到会话(不存在则创建)"
  echo "  tmux-session ls        # 列出会话"
  echo "  tmux-session kill      # 终止会话"
}

# 卸载函数
uninstall_main() {
  info "开始卸载 tmux-helper..."
  
  local rc_file
  local func_name
  local markers=("tmux-help" "tmux-session")

  while IFS= read -r rc_file; do
    for func_name in "${markers[@]}"; do
      if grep -qF "$(marker_start "$func_name")" "$rc_file"; then
        shell_remove_marked_block "$rc_file" "$(marker_start "$func_name")" "$(marker_end "$func_name")"
        success "从 $rc_file 移除 $func_name"
      fi
    done
  done < <(shell_rc_files)
  
  # 删除符号链接
  local bin_dir="$HOME/.local/bin"
  if [[ -d "$bin_dir" ]]; then
    for link_name in tmux-help tmux-session; do
      if [[ -L "$bin_dir/$link_name" ]]; then
        rm "$bin_dir/$link_name"
        info "删除符号链接: $bin_dir/$link_name"
      fi
    done
  fi
  
  # 询问是否删除配置目录
  local config_dir="$HOME/.config/tmux-helper"
  if [[ -d "$config_dir" ]]; then
    read -p "是否删除配置目录 $config_dir? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$config_dir"
      info "删除配置目录: $config_dir"
    fi
  fi
  
  success "卸载完成！"
}

# 显示帮助
show_install_help() {
  cat <<EOF
用法: add-tmux-help.sh [选项]

tmux-helper 安装脚本。

选项:
  install    安装 tmux-helper (默认)
  uninstall  卸载 tmux-helper
  -h, --help 显示此帮助信息

示例:
  bash add-tmux-help.sh           # 安装
  bash add-tmux-help.sh uninstall # 卸载
EOF
}

# 主函数
main() {
  local command="${1:-install}"
  
  case "$command" in
    install)
      install_main
      ;;
    uninstall)
      uninstall_main
      ;;
    -h|--help)
      show_install_help
      ;;
    *)
      error "未知命令: $command"
      show_install_help
      return 1
      ;;
  esac
}

# 执行主函数
main "$@"
