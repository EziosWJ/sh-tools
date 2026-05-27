#!/usr/bin/env bash
# tmux帮助显示模块
# 提供分类帮助、交互模式和搜索功能

# 帮助数据定义
declare -A HELP_DATA=(
  [session]="会话管理"
  [window]="窗口操作"
  [pane]="面板操作"
  [copy]="复制模式"
  [layout]="布局管理"
  [resize]="调整大小"
  [all]="显示全部"
)

# 快捷键数据
declare -A KEYBINDINGS=(
  # 会话管理
  ["session:1"]="Ctrl+b d      挂起/退出会话"
  ["session:2"]="Ctrl+b s      切换会话"
  ["session:3"]="Ctrl+b $      重命名会话"
  ["session:4"]="Ctrl+b (      上一个会话"
  ["session:5"]="Ctrl+b )      下一个会话"
  
  # 窗口操作
  ["window:1"]="Ctrl+b c      新建窗口"
  ["window:2"]="Ctrl+b n      下一个窗口"
  ["window:3"]="Ctrl+b p      上一个窗口"
  ["window:4"]="Ctrl+b w      窗口列表"
  ["window:5"]="Ctrl+b ,      重命名窗口"
  ["window:6"]="Ctrl+b &      关闭窗口"
  ["window:7"]="Ctrl+b 0-9    切换到指定编号窗口"
  
  # 面板操作
  ["pane:1"]="Ctrl+b %      左右分屏"
  ["pane:2"]="Ctrl+b \"      上下分屏"
  ["pane:3"]="Ctrl+b 方向键  切换面板"
  ["pane:4"]="Ctrl+b z      面板全屏/恢复"
  ["pane:5"]="Ctrl+b x      关闭面板"
  ["pane:6"]="Ctrl+b q      显示面板编号"
  ["pane:7"]="Ctrl+b {      当前面板与上一个交换"
  ["pane:8"]="Ctrl+b }      当前面板与下一个交换"
  ["pane:9"]="Ctrl+b o      切换到下一个面板（循环）"
  ["pane:10"]="Ctrl+b ;      切换到上一个面板"
  
  # 复制模式
  ["copy:1"]="Ctrl+b [      进入滚动模式"
  ["copy:2"]="q             退出滚动模式"
  ["copy:3"]="Space         开始选择文本"
  ["copy:4"]="Enter         复制选中文本"
  ["copy:5"]="Ctrl+b ]      粘贴"
  ["copy:6"]="Ctrl+b =      选择粘贴缓冲区"
  
  # 布局管理
  ["layout:1"]="Ctrl+b Space           切换面板布局"
  ["layout:2"]="Ctrl+b Alt+1           水平布局"
  ["layout:3"]="Ctrl+b Alt+2           垂直布局"
  ["layout:4"]="Ctrl+b Alt+3           主水平布局"
  ["layout:5"]="Ctrl+b Alt+4           主垂直布局"
  ["layout:6"]="Ctrl+b Alt+5           平铺布局"
  
  # 调整大小
  ["resize:1"]="Ctrl+b Ctrl+方向键    微调面板大小（按住Ctrl连按）"
  ["resize:2"]="Ctrl+b Alt+方向键     微调面板大小（5单元格）"
  ["resize:3"]="Ctrl+b :resize-pane -D 5   向下扩大5行"
  ["resize:4"]="Ctrl+b :resize-pane -U 5   向上扩大5行"
  ["resize:5"]="Ctrl+b :resize-pane -L 5   向左扩大5列"
  ["resize:6"]="Ctrl+b :resize-pane -R 5   向右扩大5列"
)

# 显示指定分类的帮助
show_category_help() {
  local category="$1"
  
  if [[ "$category" == "all" ]]; then
    show_all_help
    return
  fi
  
  if [[ -z "${HELP_DATA[$category]:-}" ]]; then
    error "未知分类: $category"
    echo "可用分类: ${!HELP_DATA[*]}"
    return 1
  fi
  
  echo "=== ${HELP_DATA[$category]} ==="
  echo ""
  
  local i=1
  while true; do
    local key="${category}:${i}"
    if [[ -n "${KEYBINDINGS[$key]:-}" ]]; then
      echo "  ${KEYBINDINGS[$key]}"
      ((i++))
    else
      break
    fi
  done
  echo ""
}

# 显示所有帮助
show_all_help() {
  echo "=== tmux 常用快捷键 ==="
  echo ""
  echo "前缀键: Ctrl+b"
  echo ""
  
  for category in session window pane copy layout resize; do
    show_category_help "$category"
  done
}

# 交互模式
interactive_mode() {
  local categories=("session" "window" "pane" "copy" "layout" "resize" "all")
  local category_list=()
  
  for cat in "${categories[@]}"; do
    category_list+=("$cat - ${HELP_DATA[$cat]}")
  done
  
  local selected
  selected=$(select_option "选择帮助分类: " "${category_list[@]}")
  
  if [[ -n "$selected" ]]; then
    local category
    category=$(echo "$selected" | cut -d' ' -f1)
    show_category_help "$category"
  fi
}

# 搜索快捷键
search_keybindings() {
  local keyword="$1"
  
  if [[ -z "$keyword" ]]; then
    error "请提供搜索关键词"
    return 1
  fi
  
  echo "搜索: $keyword"
  echo ""
  
  local found=0
  # 使用兼容的方式遍历关联数组
  local keys
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    keys=(${(k)KEYBINDINGS})
  else
    keys=("${!KEYBINDINGS[@]}")
  fi
  
  for key in "${keys[@]}"; do
    local binding="${KEYBINDINGS[$key]}"
    if [[ "$binding" == *"$keyword"* ]]; then
      echo "  $binding"
      found=$((found + 1))
    fi
  done
  
  if [[ $found -eq 0 ]]; then
    echo "未找到匹配的快捷键"
  else
    echo ""
    echo "找到 $found 个匹配项"
  fi
}

# 显示帮助信息
show_tmux_help_help() {
  cat <<EOF
用法: tmux-help [选项] [分类]

显示tmux快捷键帮助信息。

选项:
  -i, --interactive    交互模式
  -s, --search 关键词  搜索快捷键
  -h, --help           显示此帮助信息

分类:
  session   会话管理
  window    窗口操作
  pane      面板操作
  copy      复制模式
  layout    布局管理
  resize    调整大小
  all       显示全部（默认）

示例:
  tmux-help              # 显示所有帮助
  tmux-help session      # 显示会话管理帮助
  tmux-help -i           # 交互模式
  tmux-help -s copy      # 搜索包含"copy"的快捷键
EOF
}

# 主函数
tmux_help_main() {
  # 加载配置
  load_config
  
  local category=""
  local interactive=false
  local search_keyword=""
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--interactive)
        interactive=true
        shift
        ;;
      -s|--search)
        if [[ -z "${2:-}" ]]; then
          error "选项 $1 需要参数"
          return 1
        fi
        search_keyword="$2"
        shift 2
        ;;
      -h|--help)
        show_tmux_help_help
        return 0
        ;;
      -*)
        error "未知选项: $1"
        show_tmux_help_help
        return 1
        ;;
      *)
        if [[ -z "$category" ]]; then
          category="$1"
        else
          error "多余的参数: $1"
          return 1
        fi
        shift
        ;;
    esac
  done
  
  # 执行相应功能
  if [[ "$interactive" == true ]]; then
    interactive_mode
  elif [[ -n "$search_keyword" ]]; then
    search_keybindings "$search_keyword"
  elif [[ -n "$category" ]]; then
    show_category_help "$category"
  else
    show_all_help
  fi
}