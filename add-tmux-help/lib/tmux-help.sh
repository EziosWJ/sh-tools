#!/usr/bin/env bash
# tmux帮助显示模块
# 提供分类帮助、交互模式和搜索功能

# 帮助数据定义
declare -A HELP_DATA=(
  [session]="会话管理 (Session)"
  [window]="窗口操作 (Window)"
  [pane]="面板操作 (Pane)"
  [copy]="复制模式 (Copy/Scroll)"
  [layout]="布局管理 (Layout)"
  [resize]="调整大小 (Resize)"
  [all]="显示全部"
)

# 分类描述
declare -A HELP_DESC=(
  [session]="Session 是 tmux 的顶层容器，可以挂起(detach)后随时恢复，适合长期运行任务"
  [window]="Window 是 Session 中的标签页，类似浏览器标签，每个 Session 可有多个 Window"
  [pane]="Pane 是 Window 中的分屏区域，可以在一个 Window 中同时查看多个终端"
  [copy]="Copy 模式用于滚动查看历史输出和复制文本"
  [layout]="Layout 控制 Pane 的排列方式"
  [resize]="调整 Pane 的大小比例"
)

# 快捷键和命令数据
declare -A KEYBINDINGS=(
  # 会话管理 - 快捷键
  ["session:1"]="Ctrl+b d            挂起当前会话(detach)，会话在后台继续运行"
  ["session:2"]="Ctrl+b s            列出所有会话并切换"
  ["session:3"]="Ctrl+b $            重命名当前会话"
  ["session:4"]="Ctrl+b (            切换到上一个会话"
  ["session:5"]="Ctrl+b )            切换到下一个会话"
  # 会话管理 - 命令行
  ["session:6"]=""
  ["session:7"]="命令行操作:"
  ["session:8"]="tmux                        启动新会话"
  ["session:9"]="tmux new -s <名称>          创建命名会话"
  ["session:10"]="tmux ls                     列出所有会话"
  ["session:11"]="tmux attach -t <名称>       恢复(detached)会话"
  ["session:12"]="tmux kill-session -t <名称>  终止指定会话"
  # 会话管理 - 工作流
  ["session:13"]=""
  ["session:14"]="常用工作流:"
  ["session:15"]="1. tmux new -s dev          创建开发会话"
  ["session:16"]="2. Ctrl+b d                 挂起(工作在后台继续)"
  ["session:17"]="3. tmux attach -t dev       回来继续工作"
  ["session:18"]="4. tmux switch-client -t x  在tmux内切换到另一个会话"

  # 窗口操作
  ["window:1"]="Ctrl+b c              新建窗口"
  ["window:2"]="Ctrl+b n              下一个窗口"
  ["window:3"]="Ctrl+b p              上一个窗口"
  ["window:4"]="Ctrl+b w              窗口列表(可选择切换)"
  ["window:5"]="Ctrl+b ,              重命名当前窗口"
  ["window:6"]="Ctrl+b &              关闭当前窗口(需确认)"
  ["window:7"]="Ctrl+b 0-9            切换到指定编号窗口"
  ["window:8"]=""
  ["window:9"]="命令行: tmux list-windows -t <session>  列出会话的所有窗口"

  # 面板操作
  ["pane:1"]="Ctrl+b %              左右分屏(垂直分割)"
  ["pane:2"]="Ctrl+b \"              上下分屏(水平分割)"
  ["pane:3"]="Ctrl+b 方向键         切换到相邻面板"
  ["pane:4"]="Ctrl+b z              当前面板最大化/恢复"
  ["pane:5"]="Ctrl+b x              关闭当前面板(需确认)"
  ["pane:6"]="Ctrl+b q              显示面板编号(按数字跳转)"
  ["pane:7"]="Ctrl+b {              当面板与上一个交换位置"
  ["pane:8"]="Ctrl+b }              当面板与下一个交换位置"
  ["pane:9"]="Ctrl+b o              循环切换到下一个面板"
  ["pane:10"]="Ctrl+b ;             切换到上一个面板"
  ["pane:11"]=""
  ["pane:12"]="提示: Alt+h/j/k/l 可在 ~/.tmux.conf 中配置为面板快速导航"

  # 复制模式
  ["copy:1"]="Ctrl+b [              进入复制/滚动模式"
  ["copy:2"]="  q                   退出滚动模式"
  ["copy:3"]="  Space               开始选择文本"
  ["copy:4"]="  Enter               复制选中文本"
  ["copy:5"]="  /                   向下搜索"
  ["copy:6"]="  ?                   向上搜索"
  ["copy:7"]="Ctrl+b ]              粘贴已复制的内容"
  ["copy:8"]="Ctrl+b =              从粘贴缓冲区列表中选择"
  ["copy:9"]=""
  ["copy:10"]="提示: 复制模式中支持 vi/emacs 按键，通过 set -g mode-keys vi 切换"

  # 布局管理
  ["layout:1"]="Ctrl+b Space        循环切换预设布局"
  ["layout:2"]="Ctrl+b Alt+1        even-horizontal (左右均分)"
  ["layout:3"]="Ctrl+b Alt+2        even-vertical   (上下均分)"
  ["layout:4"]="Ctrl+b Alt+3        main-horizontal (上一大下多小)"
  ["layout:5"]="Ctrl+b Alt+4        main-vertical   (左一大右多小)"
  ["layout:6"]="Ctrl+b Alt+5        tiled           (网格平铺)"

  # 调整大小
  ["resize:1"]="Ctrl+b Ctrl+方向键   微调面板大小(1单元格)"
  ["resize:2"]="Ctrl+b Alt+方向键    微调面板大小(5单元格)"
  ["resize:3"]=""
  ["resize:4"]="命令行方式:"
  ["resize:5"]=":resize-pane -D 5    向下扩大5行"
  ["resize:6"]=":resize-pane -U 5    向上扩大5行"
  ["resize:7"]=":resize-pane -L 5    向左扩大5列"
  ["resize:8"]=":resize-pane -R 5    向右扩大5列"
)

# 显示分隔线
print_separator() {
  echo "------------------------------------------------------------"
}

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

  echo ""
  echo "  ${HELP_DATA[$category]}"
  print_separator

  # 显示分类描述
  if [[ -n "${HELP_DESC[$category]:-}" ]]; then
    echo "  ${HELP_DESC[$category]}"
    echo ""
  fi

  local i=1
  while true; do
    local key="${category}:${i}"
    # 检查 key 是否存在（区分空值和不存在）
    local has_key=false
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      [[ -n "${(k)KEYBINDINGS[(Ie)$key]:-}" ]] && has_key=true
    else
      [[ -v "KEYBINDINGS[$key]" ]] && has_key=true
    fi

    if $has_key; then
      local val="${KEYBINDINGS[$key]}"
      if [[ -n "$val" ]]; then
        echo "  $val"
      fi
      ((i++))
    else
      break
    fi
  done
  echo ""
}

# 显示所有帮助
show_all_help() {
  echo ""
  echo "  tmux 常用快捷键与命令速查"
  echo "  前缀键: Ctrl+b (所有快捷键先按前缀键再按功能键)"
  print_separator
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
  print_separator

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
    if [[ -n "$binding" ]] && [[ "$binding" == *"$keyword"* ]]; then
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

显示tmux快捷键和命令帮助。

选项:
  -i, --interactive    交互模式(选择分类查看)
  -s, --search 关键词  搜索快捷键和命令
  -h, --help           显示此帮助信息

分类:
  session   会话管理 - 创建、切换、挂起、恢复
  window    窗口操作 - 新建、切换、关闭
  pane      面板操作 - 分屏、导航、交换
  copy      复制模式 - 滚动、搜索、复制粘贴
  layout    布局管理 - 面板排列方式
  resize    调整大小 - 面板尺寸调整
  all       显示全部（默认）

示例:
  tmux-help              # 显示所有帮助
  tmux-help session      # 显示会话管理帮助
  tmux-help -i           # 交互模式
  tmux-help -s 分屏      # 搜索包含"分屏"的内容
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
