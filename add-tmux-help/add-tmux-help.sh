#!/usr/bin/env bash
set -Eeuo pipefail

# 进程替换输入是一次性管道；先保存完整入口，供菜单重复启动子操作。
if [[ "$0" == /dev/fd/* || "$0" == /proc/self/fd/* ]]; then
  menu_script="$(mktemp)"
  trap 'rm -f -- "$menu_script"' EXIT
  curl -fsSL "${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}/add-tmux-help/add-tmux-help.sh" -o "$menu_script"
  bash "$menu_script" "$@"
  exit $?
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
RUNTIME_DIR="${ADD_TMUX_HELP_RUNTIME_DIR:-$HOME/.local/share/sh-tools/add-tmux-help}"
BIN_DIR="${ADD_TMUX_HELP_BIN_DIR:-$HOME/.local/bin}"
RC_DIR="${ADD_TMUX_HELP_RC_DIR:-$HOME}"
ASSET_DIR="$SCRIPT_DIR"

# 无仓库执行时，下载运行所需模块。
if [[ ! -f "$ASSET_DIR/lib/utils.sh" ]]; then
  ASSET_DIR="$RUNTIME_DIR"
  mkdir -p "$ASSET_DIR/lib"
  for file in utils.sh tmux-help.sh tmux-session.sh; do
    curl -fsSL "$REPO_RAW_BASE/add-tmux-help/lib/$file" -o "$ASSET_DIR/lib/$file"
  done
fi
source "$ASSET_DIR/lib/utils.sh"

run_module() {
  local module="$1"
  shift
  bash -e -o pipefail -c '
    source "$1/lib/utils.sh"
    source "$1/lib/$2.sh"
    module="$2"
    shift 2
    "${module//-/_}_main" "$@"
  ' _ "$ASSET_DIR" "$module" "$@"
}

# 只识别本工具标记或与 v1 生成模板完全一致的普通文件，不执行目标内容。
command_kind() {
  local target="$1" module="$2" legacy_dir
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    printf 'missing\n'
  elif [[ -f "$target" && ! -L "$target" ]]; then
    if grep -qFx '# sh-tools tmux command' "$target"; then
      printf 'v2\n'
      return
    fi
    legacy_dir="$(sed -n '2s|^source "\(.*\)/lib/utils.sh"$|\1|p' "$target")"
    if [[ -n "$legacy_dir" ]] && cmp -s "$target" <(
      printf '#!/usr/bin/env bash\nsource "%s/lib/utils.sh"\nsource "%s/lib/%s.sh"\n%s_main "$@"\n' \
        "$legacy_dir" "$legacy_dir" "$module" "${module//-/_}"
    ); then
      printf 'legacy\n'
    else
      printf 'unknown\n'
    fi
  else
    printf 'unknown\n'
  fi
}

backup_legacy_command() {
  local target="$1" backup_dir
  backup_dir="$(mktemp -d "$BIN_DIR/.sh-tools-backup.XXXXXX")"
  mv -- "$target" "$backup_dir/"
  info "旧命令已备份：$backup_dir/$(basename "$target")"
}

# 只更新旧安装器留下的标记块，避免 shell 函数直接 source Bash 模块。
update_shell_bindings() {
  local mode="$1" rc module fragment temporary backup
  for rc in "$RC_DIR/.bashrc" "$RC_DIR/.zshrc"; do
    [[ -f "$rc" ]] || continue
    for module in tmux-help tmux-session; do
      grep -qFx "# >>> $module >>>" "$rc" || continue
      fragment="$(mktemp)"
      temporary="$(mktemp)"
      if [[ "$mode" == install ]]; then
        {
          printf '# >>> %s >>>\n' "$module"
          printf '%s() {\n  command %q "$@"\n}\n' "$module" "$BIN_DIR/$module"
          printf '# <<< %s <<<\n' "$module"
        } > "$fragment"
      fi
      if ! awk -v begin="# >>> $module >>>" -v end="# <<< $module <<<" -v fragment="$fragment" '
        $0 == begin {
          starts++; inside=1
          while ((getline line < fragment) > 0) print line
          close(fragment)
          next
        }
        $0 == end { ends++; inside=0; next }
        !inside { print }
        END { if (starts != 1 || ends != 1 || inside) exit 1 }
      ' "$rc" > "$temporary"; then
        rm -f -- "$fragment" "$temporary"
        error "标记块不完整或重复，未修改：$rc（$module）"
        return 1
      fi
      if ! cmp -s "$rc" "$temporary"; then
        backup="$(mktemp "$rc.sh-tools-backup.XXXXXX")"
        cp -p -- "$rc" "$backup"
        cp -- "$temporary" "$rc"
        info "已更新 $rc 的 $module 绑定；原文件备份：$backup"
      fi
      rm -f -- "$fragment" "$temporary"
    done
  done
}

install_main() {
  local file module target kind
  # 先检查全部目标，避免遇到第二个冲突时已经覆盖第一个命令。
  for module in tmux-help tmux-session; do
    target="$BIN_DIR/$module"
    if [[ "$(command_kind "$target" "$module")" == "unknown" ]]; then
      error "目标已存在且无法确认为本工具命令：$target，已保留，请先处理该文件再安装。"
      return 1
    fi
  done
  mkdir -p "$RUNTIME_DIR/lib" "$BIN_DIR"
  for file in utils.sh tmux-help.sh tmux-session.sh; do
    if [[ ! "$ASSET_DIR/lib/$file" -ef "$RUNTIME_DIR/lib/$file" ]]; then
      cp "$ASSET_DIR/lib/$file" "$RUNTIME_DIR/lib/$file"
    fi
  done
  for module in tmux-help tmux-session; do
    target="$BIN_DIR/$module"
    kind="$(command_kind "$target" "$module")"
    if [[ "$kind" == "legacy" ]]; then
      backup_legacy_command "$target"
    fi
    {
      printf '#!/usr/bin/env bash\n# sh-tools tmux command\nset -Eeuo pipefail\n'
      printf 'source %q\n' "$RUNTIME_DIR/lib/utils.sh"
      printf 'source %q\n' "$RUNTIME_DIR/lib/$module.sh"
      printf '%s_main "$@"\n' "${module//-/_}"
    } > "$target"
    chmod +x "$target"
  done
  update_shell_bindings install
  success "已安装 tmux-session 和 tmux-help 到 $BIN_DIR"
  info "若当前终端已加载旧版函数，请重新打开终端后使用。"
  case ":${PATH}:" in
    *":$BIN_DIR:"*) ;;
    *) printf '当前 PATH 未包含该目录；可直接执行：%q\n' "$BIN_DIR/tmux-session" ;;
  esac
}

uninstall_main() {
  update_shell_bindings uninstall
  local module target
  for module in tmux-help tmux-session; do
    target="$BIN_DIR/$module"
    case "$(command_kind "$target" "$module")" in
      v2)
        rm -- "$target"
        success "已移除命令：$target" ;;
      legacy) backup_legacy_command "$target" ;;
      unknown) warn "未移除无法识别的命令：$target；安装时仍会提示此冲突。" ;;
      missing) info "命令未安装：$target" ;;
    esac
  done
  info "会话和运行时文件保留；不会终止任何 tmux 会话。"
}

show_install_help() {
  printf '%s\n' \
    '用法: bash add-tmux-help.sh [menu|install|uninstall|sessions|help]' \
    '  无参数进入菜单；sessions 打开会话管理。' \
    '  keys [分类] 查看快捷键，keys -i 打开分类菜单。' \
    '  install 安装用户命令，并修正旧安装器留下的 shell 绑定。'
}

main() {
  local action="${1:-menu}" choice
  case "$action" in
    menu)
      while true; do
        printf '\ntmux 工具\n1) 会话管理\n2) 快捷键帮助\n3) 安装 tmux-session / tmux-help 命令\n4) 卸载命令\n0) 返回上一级\n'
        read -r -p "请选择编号: " choice || return 0
        case "$choice" in
          1) action="sessions" ;;
          2) action="keys" ;;
          3) action="install" ;;
          4) action="uninstall" ;;
          0) return 0 ;;
          *) error "输入无效。"; continue ;;
        esac
        if [[ "$action" == "keys" ]]; then
          bash "$0" keys -i || error "操作失败，请检查上方错误。"
        else
          bash "$0" "$action" || error "操作失败，请检查上方错误。"
        fi
      done ;;
    sessions) shift; run_module tmux-session "$@" ;;
    keys) shift; run_module tmux-help "$@" ;;
    install) install_main ;;
    uninstall) uninstall_main ;;
    help|-h|--help) show_install_help ;;
    *) error "未知命令：$action"; return 1 ;;
  esac
}

main "$@"
