#!/usr/bin/env bash
# tmux会话管理模块
# 提供会话的创建、列表、切换、终止、保存和恢复功能

# 会话模板
declare -A SESSION_TEMPLATES=(
  ["web-project"]="npm run dev"
  ["python-api"]="python manage.py runserver"
  ["node-server"]="node server.js"
  ["go-service"]="go run main.go"
  ["rust-project"]="cargo run"
)

# 从配置文件加载模板
load_templates() {
  local template_file
  template_file=$(resolve_path "$TMUX_HELPER_TEMPLATE_FILE")
  
  if [[ ! -f "$template_file" ]]; then
    debug "模板文件不存在: $template_file"
    return 0
  fi
  
  debug "加载模板文件: $template_file"
  
  # 清除硬编码的模板
  unset SESSION_TEMPLATES
  declare -gA SESSION_TEMPLATES
  
  while IFS='|' read -r name directory command; do
    # 跳过空行和注释
    [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue
    
    # 去除首尾空格
    name=$(echo "$name" | xargs)
    directory=$(echo "$directory" | xargs)
    command=$(echo "$command" | xargs)
    
    # 去除引号
    name="${name%\"}"
    name="${name#\"}"
    directory="${directory%\"}"
    directory="${directory#\"}"
    command="${command%\"}"
    command="${command#\"}"
    
    if [[ -n "$name" && -n "$command" ]]; then
      SESSION_TEMPLATES["$name"]="$command"
      # 存储目录信息
      eval "TEMPLATE_DIR_${name//[^a-zA-Z0-9]/_}=\"$directory\""
      debug "加载模板: $name -> $command (目录: $directory)"
    fi
  done < "$template_file"
}

# 创建会话
session_create() {
  local name="$1"
  local directory="${2:-$(pwd)}"
  
  # 验证会话名称
  if ! validate_session_name "$name"; then
    return 1
  fi
  
  # 检查会话是否已存在
  if tmux has-session -t "$name" 2>/dev/null; then
    error "会话 '$name' 已存在"
    return 1
  fi
  
  # 解析目录路径
  directory=$(resolve_path "$directory")
  
  # 检查目录是否存在
  if [[ ! -d "$directory" ]]; then
    error "目录不存在: $directory"
    return 1
  fi
  
  # 创建会话
  tmux new-session -d -s "$name" -c "$directory"
  success "创建会话: $name (目录: $directory)"
  
  # 如果在tmux中，切换到新会话
  if in_tmux; then
    tmux switch-client -t "$name"
  fi
}

# 列出所有会话
session_list() {
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
  
  if [[ -z "$sessions" ]]; then
    info "没有活动的会话"
    return 0
  fi
  
  echo "活动会话:"
  echo ""
  
  while IFS= read -r session; do
    local windows
    windows=$(tmux list-windows -t "$session" -F "#{window_name}" 2>/dev/null | wc -l)
    local attached
    attached=$(tmux list-clients -t "$session" 2>/dev/null | wc -l)
    
    printf "  %-20s %d 个窗口" "$session" "$windows"
    if [[ $attached -gt 0 ]]; then
      printf " (已连接)"
    fi
    echo ""
  done <<< "$sessions"
}

# 交互式切换会话
session_switch() {
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
  
  if [[ -z "$sessions" ]]; then
    info "没有活动的会话"
    return 0
  fi
  
  local session_list
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    session_list=("${(@f)sessions}")
  else
    mapfile -t session_list <<< "$sessions"
  fi
  
  local selected
  selected=$(select_option "选择会话: " "${session_list[@]}")
  
  if [[ -n "$selected" ]]; then
    if in_tmux; then
      tmux switch-client -t "$selected"
    else
      tmux attach -t "$selected"
    fi
  fi
}

# 终止会话
session_kill() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    error "请指定会话名称"
    return 1
  fi
  
  if ! tmux has-session -t "$name" 2>/dev/null; then
    error "会话 '$name' 不存在"
    return 1
  fi
  
  tmux kill-session -t "$name"
  success "已终止会话: $name"
}

# 保存会话布局
session_save() {
  local name="${1:-$(tmux display-message -p '#{session_name}')}"
  local save_dir
  save_dir=$(resolve_path "$TMUX_HELPER_SESSION_DIR")
  
  ensure_directory "$save_dir"
  
  local save_file="$save_dir/${name}.json"
  local created
  created=$(date -Iseconds)
  
  # 获取会话信息
  local windows=()
  local window_names
  window_names=$(tmux list-windows -t "$name" -F "#{window_name}" 2>/dev/null)
  
  while IFS= read -r window_name; do
    if [[ -z "$window_name" ]]; then
      continue
    fi
    
    # 获取窗口布局
    local layout
    layout=$(tmux list-windows -t "$name" -F "#{window_layout}" 2>/dev/null | head -1)
    
    # 获取面板信息
    local panes=()
    local pane_info
    pane_info=$(tmux list-panes -t "$name:$window_name" -F "#{pane_current_path}" 2>/dev/null)
    
    while IFS= read -r pane_path; do
      if [[ -n "$pane_path" ]]; then
        panes+=("{\"directory\": \"$pane_path\"}")
      fi
    done <<< "$pane_info"
    
    # 构建窗口JSON
    local panes_json
    panes_json=$(printf '%s,' "${panes[@]}")
    panes_json="[${panes_json%,}]"
    
    windows+=("{\"name\": \"$window_name\", \"layout\": \"$layout\", \"panes\": $panes_json}")
  done <<< "$window_names"
  
  # 构建完整JSON
  local windows_json
  windows_json=$(printf '%s,' "${windows[@]}")
  windows_json="[${windows_json%,}]"
  
  local json="{\"name\": \"$name\", \"created\": \"$created\", \"windows\": $windows_json}"
  
  # 保存到文件
  echo "$json" > "$save_file"
  success "会话已保存: $save_file"
}

# 恢复会话布局
session_restore() {
  local name="$1"
  local save_dir
  save_dir=$(resolve_path "$TMUX_HELPER_SESSION_DIR")
  local save_file="$save_dir/${name}.json"
  
  if [[ ! -f "$save_file" ]]; then
    error "会话备份不存在: $save_file"
    return 1
  fi
  
  # 读取JSON
  local json
  json=$(cat "$save_file")
  
  # 解析窗口数量
  local window_count
  if check_command jq; then
    window_count=$(echo "$json" | jq '.windows | length')
  else
    window_count=$(echo "$json" | grep -o '"name"' | wc -l)
  fi
  
  # 创建新会话
  if tmux has-session -t "$name" 2>/dev/null; then
    error "会话 '$name' 已存在，请先终止"
    return 1
  fi
  
  tmux new-session -d -s "$name"
  
  # 恢复窗口
  for ((i=0; i<window_count; i++)); do
    local window_name
    if check_command jq; then
      window_name=$(echo "$json" | jq -r ".windows[$i].name")
    else
      window_name="window-$i"
    fi
    
    if [[ $i -eq 0 ]]; then
      tmux rename-window -t "$name:0" "$window_name"
    else
      tmux new-window -t "$name" -n "$window_name"
    fi
    
    # 恢复面板目录
    local pane_count
    if check_command jq; then
      pane_count=$(echo "$json" | jq ".windows[$i].panes | length")
    else
      pane_count=1
    fi
    
    for ((j=0; j<pane_count; j++)); do
      local pane_dir
      if check_command jq; then
        pane_dir=$(echo "$json" | jq -r ".windows[$i].panes[$j].directory // empty")
      fi
      
      if [[ -n "$pane_dir" ]] && [[ -d "$pane_dir" ]]; then
        if [[ $j -eq 0 ]]; then
          tmux send-keys -t "$name:$window_name" "cd $pane_dir" Enter
        else
          tmux split-window -t "$name:$window_name" -c "$pane_dir"
        fi
      fi
    done
  done
  
  success "会话已恢复: $name"
}

# 列出模板
template_list() {
  echo "可用模板:"
  echo ""
  
  # 使用兼容的方式遍历关联数组
  local keys
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    keys=(${(k)SESSION_TEMPLATES})
    # 去除引号
    keys=("${(@)keys//\"/}")
  else
    keys=("${!SESSION_TEMPLATES[@]}")
  fi
  
  for template in "${keys[@]}"; do
    local command="${SESSION_TEMPLATES[$template]}"
    local dir_var="TEMPLATE_DIR_${template//[^a-zA-Z0-9]/_}"
    local directory=""
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      directory="${(P)dir_var:-未指定}"
    else
      directory="${!dir_var:-未指定}"
    fi
    
    printf "  %-20s %-30s %s\n" "$template" "$command" "目录: $directory"
  done
  
  echo ""
  echo "配置文件: $TMUX_HELPER_TEMPLATE_FILE"
}

# 从模板创建会话
template_create() {
  local template_name="$1"
  local session_name="${2:-$template_name}"
  
  # 检查模板是否存在
  if [[ -z "${SESSION_TEMPLATES[$template_name]:-}" ]]; then
    error "模板 '$template_name' 不存在"
    template_list
    return 1
  fi
  
  local command="${SESSION_TEMPLATES[$template_name]}"
  local directory=""
  
  # 获取模板目录
  local dir_var="TEMPLATE_DIR_${template_name//[^a-zA-Z0-9]/_}"
  if [[ -n "${!dir_var:-}" ]]; then
    directory="${!dir_var}"
  fi
  
  # 创建会话
  if [[ -n "$directory" ]]; then
    session_create "$session_name" "$directory"
  else
    session_create "$session_name"
  fi
  
  # 发送启动命令
  tmux send-keys -t "$session_name" "$command" Enter
  
  success "从模板创建会话: $session_name (命令: $command)"
}

# 显示当前状态
session_status() {
  if ! in_tmux; then
    info "当前不在tmux会话中"
    echo ""
    echo "可用命令:"
    echo "  tmux-session create <名称> [目录]  # 创建会话"
    echo "  tmux-session list                  # 列出会话"
    echo "  tmux-session switch                # 切换会话"
    echo "  tmux attach                        # 连接到会话"
    return 0
  fi
  
  local session_name
  session_name=$(tmux display-message -p '#{session_name}')
  local window_name
  window_name=$(tmux display-message -p '#{window_name}')
  local pane_count
  pane_count=$(tmux display-message -p '#{window_panes}')
  local client_count
  client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l)
  
  echo "当前状态:"
  echo ""
  echo "  会话: $session_name"
  echo "  窗口: $window_name"
  echo "  面板数: $pane_count"
  echo "  客户端数: $client_count"
  echo "  tmux版本: $(get_tmux_version)"
}

# 显示帮助信息
show_session_help() {
  cat <<EOF
用法: tmux-session <命令> [参数]

tmux会话管理工具。

命令:
  create <名称> [目录]    创建新会话
  list                   列出所有会话
  switch                 交互式切换会话
  kill <名称>            终止会话
  save [名称]            保存当前会话布局
  restore <名称>         恢复会话布局
  template list          列出预设模板
  template create <模板> 从模板创建会话
  status                 显示当前状态

示例:
  tmux-session create myproject ~/projects/myapp
  tmux-session list
  tmux-session switch
  tmux-session save
  tmux-session restore myproject
  tmux-session template create web-project
EOF
}

# 主函数
tmux_session_main() {
  # 加载配置
  load_config
  
  # 加载模板
  load_templates
  
  local command="${1:-}"
  shift || true
  
  case "$command" in
    create)
      if [[ $# -lt 1 ]]; then
        error "用法: tmux-session create <名称> [目录]"
        return 1
      fi
      session_create "$@"
      ;;
    list)
      session_list
      ;;
    switch)
      session_switch
      ;;
    kill)
      if [[ $# -lt 1 ]]; then
        error "用法: tmux-session kill <名称>"
        return 1
      fi
      session_kill "$1"
      ;;
    save)
      session_save "$@"
      ;;
    restore)
      if [[ $# -lt 1 ]]; then
        error "用法: tmux-session restore <名称>"
        return 1
      fi
      session_restore "$1"
      ;;
    template)
      local subcommand="${1:-}"
      shift || true
      case "$subcommand" in
        list)
          template_list
          ;;
        create)
          if [[ $# -lt 1 ]]; then
            error "用法: tmux-session template create <模板> [会话名]"
            return 1
          fi
          template_create "$@"
          ;;
        *)
          error "未知模板命令: $subcommand"
          show_session_help
          return 1
          ;;
      esac
      ;;
    status)
      session_status
      ;;
    -h|--help|"")
      show_session_help
      ;;
    *)
      error "未知命令: $command"
      show_session_help
      return 1
      ;;
  esac
}