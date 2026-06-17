#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"
RUNTIME_DIR="${SH_TOOLS_AGENTS_RUNTIME_DIR:-$HOME/.local/share/sh-tools/agents}"
CONFIG_DIR="${SH_TOOLS_CONFIG_DIR:-$HOME/.config/sh-tools}/agents/claude-code"
PROFILES_DIR="$CONFIG_DIR/profiles"
WRAPPERS_DIR="$CONFIG_DIR/wrappers"
if [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/../lib/common.sh"
else
  mkdir -p "$RUNTIME_DIR/lib"
  curl -fsSL -o "$RUNTIME_DIR/lib/common.sh" "$REPO_RAW_BASE/agents/lib/common.sh"
  # shellcheck disable=SC1090
  source "$RUNTIME_DIR/lib/common.sh"
fi

ensure_config_dirs() {
  mkdir -p "$PROFILES_DIR" "$WRAPPERS_DIR" "$HOME/.local/bin"
}

prompt_value() {
  local prompt="$1"
  local default_value="${2:-}"
  local answer

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt [$default_value]: " answer || return 1
    printf '%s\n' "${answer:-$default_value}"
  else
    read -r -p "$prompt: " answer || return 1
    printf '%s\n' "$answer"
  fi
}

sanitize_profile_name() {
  local name="$1"

  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    error "profile 名只能包含字母、数字、点、下划线和短横线。"
    return 1
  fi

  printf '%s\n' "$name"
}

profile_path() {
  local name

  name="$(sanitize_profile_name "$1")" || return 1
  printf '%s/%s.env\n' "$PROFILES_DIR" "$name"
}

write_env_line() {
  local file="$1"
  local key="$2"
  local value="$3"

  [[ -n "$value" ]] || return 0
  printf '%s=%q\n' "$key" "$value" >> "$file"
}

load_profile_env() {
  local profile="$1"
  local file

  file="$(profile_path "$profile")" || return 1
  if [[ ! -f "$file" ]]; then
    error "profile 不存在：$profile"
    return 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

config_list() {
  ensure_config_dirs
  local file
  local found=0

  for file in "$PROFILES_DIR"/*.env; do
    [[ -e "$file" ]] || continue
    found=1
    basename "$file" .env
  done

  if ((found == 0)); then
    warn "暂无 Claude Code profile。"
  fi
}

config_add() {
  ensure_config_dirs
  local name
  local file
  local base_url
  local token
  local model
  local sonnet_model
  local sonnet_model_name
  local opus_model
  local opus_model_name
  local haiku_model
  local haiku_model_name
  local attribution_header
  local model_discovery
  local custom_headers

  name="$(prompt_value "请输入 profile 名称，例如 newapi 或 xiaomi")" || return 1
  name="$(sanitize_profile_name "$name")" || return 1
  file="$(profile_path "$name")" || return 1

  if [[ -f "$file" ]] && ! confirm "profile 已存在，是否覆盖？"; then
    warn "已取消。"
    return 0
  fi

  base_url="$(prompt_value "ANTHROPIC_BASE_URL")" || return 1
  token="$(prompt_value "ANTHROPIC_AUTH_TOKEN")" || return 1
  model="$(prompt_value "ANTHROPIC_MODEL" "")" || return 1
  sonnet_model="$(prompt_value "ANTHROPIC_DEFAULT_SONNET_MODEL" "")" || return 1
  sonnet_model_name="$(prompt_value "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME" "")" || return 1
  opus_model="$(prompt_value "ANTHROPIC_DEFAULT_OPUS_MODEL" "")" || return 1
  opus_model_name="$(prompt_value "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME" "")" || return 1
  haiku_model="$(prompt_value "ANTHROPIC_DEFAULT_HAIKU_MODEL" "")" || return 1
  haiku_model_name="$(prompt_value "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME" "")" || return 1
  attribution_header="$(prompt_value "CLAUDE_CODE_ATTRIBUTION_HEADER，小米不兼容时通常填 0" "")" || return 1
  model_discovery="$(prompt_value "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY" "1")" || return 1
  custom_headers="$(prompt_value "ANTHROPIC_CUSTOM_HEADERS，JSON 格式，可留空" "")" || return 1

  : > "$file"
  write_env_line "$file" "ANTHROPIC_BASE_URL" "$base_url"
  write_env_line "$file" "ANTHROPIC_AUTH_TOKEN" "$token"
  write_env_line "$file" "ANTHROPIC_MODEL" "$model"
  write_env_line "$file" "ANTHROPIC_DEFAULT_SONNET_MODEL" "$sonnet_model"
  write_env_line "$file" "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME" "$sonnet_model_name"
  write_env_line "$file" "ANTHROPIC_DEFAULT_OPUS_MODEL" "$opus_model"
  write_env_line "$file" "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME" "$opus_model_name"
  write_env_line "$file" "ANTHROPIC_DEFAULT_HAIKU_MODEL" "$haiku_model"
  write_env_line "$file" "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME" "$haiku_model_name"
  write_env_line "$file" "CLAUDE_CODE_ATTRIBUTION_HEADER" "$attribution_header"
  write_env_line "$file" "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY" "$model_discovery"
  write_env_line "$file" "ANTHROPIC_CUSTOM_HEADERS" "$custom_headers"

  chmod 600 "$file"
  success "已保存 Claude Code profile：$file"
}

config_status() {
  local profile="${1:-}"
  local file

  ensure_config_dirs
  if [[ -z "$profile" ]]; then
    info "Claude Code config 目录："
    print_status "config dir" "$CONFIG_DIR"
    print_status "profiles dir" "$PROFILES_DIR"
    print_status "wrappers dir" "$WRAPPERS_DIR"
    echo "profiles:"
    config_list
    return 0
  fi

  file="$(profile_path "$profile")" || return 1
  if [[ ! -f "$file" ]]; then
    error "profile 不存在：$profile"
    return 1
  fi

  info "Claude Code profile：$profile"
  print_status "file" "$file"
  grep -E '^(ANTHROPIC_BASE_URL|ANTHROPIC_MODEL|ANTHROPIC_DEFAULT_|CLAUDE_CODE_|ANTHROPIC_CUSTOM_HEADERS)=' "$file" || true
  if grep -Eq '^(ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY)=' "$file"; then
    print_status "token" "present"
  else
    print_status "token" "missing"
  fi
}

config_edit() {
  local profile="$1"
  local file
  local editor="${EDITOR:-vi}"

  ensure_config_dirs
  file="$(profile_path "$profile")" || return 1
  if [[ ! -f "$file" ]]; then
    error "profile 不存在：$profile"
    return 1
  fi

  "$editor" "$file"
}

add_custom_headers_args() {
  local custom_headers="${ANTHROPIC_CUSTOM_HEADERS:-}"
  local header
  local parsed_headers

  [[ -n "$custom_headers" ]] || return 0

  if command_exists jq; then
    if ! parsed_headers="$(printf '%s\n' "$custom_headers" | jq -r 'to_entries[] | "\(.key): \(.value)"' 2>/dev/null)"; then
      warn "ANTHROPIC_CUSTOM_HEADERS 不是合法 JSON，models 请求不会附加自定义 headers。"
      return 0
    fi

    while IFS= read -r header; do
      [[ -n "$header" ]] || continue
      CURL_ARGS+=(-H "$header")
    done <<< "$parsed_headers"
  else
    warn "检测到 ANTHROPIC_CUSTOM_HEADERS，但未安装 jq，models 请求不会附加自定义 headers。"
  fi
}

fetch_models_json() {
  local profile="$1"
  local base_url
  local token
  local url

  require_commands curl || return 1
  load_profile_env "$profile" || return 1

  base_url="${ANTHROPIC_BASE_URL:-}"
  token="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-}}"
  if [[ -z "$base_url" ]]; then
    error "$profile 未配置 ANTHROPIC_BASE_URL。"
    return 1
  fi
  if [[ -z "$token" ]]; then
    warn "$profile 未配置 token，将不带 Authorization 请求 models。"
  fi

  url="${base_url%/}/v1/models"
  CURL_ARGS=(-fsSL "$url")
  if [[ -n "$token" ]]; then
    CURL_ARGS+=(-H "Authorization: Bearer $token")
  fi
  add_custom_headers_args

  curl "${CURL_ARGS[@]}"
}

parse_model_ids() {
  if command_exists jq; then
    jq -r '.data[]?.id // .models[]?.id // .[]?.id // empty'
  else
    sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
  fi
}

config_models() {
  local profile="$1"

  fetch_models_json "$profile" | parse_model_ids | sed '/^$/d'
}

replace_or_append_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file

  tmp_file="$(mktemp)"
  if [[ -f "$file" ]]; then
    grep -Ev "^${key}=" "$file" > "$tmp_file" || true
  fi
  printf '%s=%q\n' "$key" "$value" >> "$tmp_file"
  mv "$tmp_file" "$file"
  chmod 600 "$file"
}

config_set_model() {
  local profile="$1"
  local file
  local models=()
  local model
  local selected
  local index

  ensure_config_dirs
  file="$(profile_path "$profile")" || return 1
  [[ -f "$file" ]] || {
    error "profile 不存在：$profile"
    return 1
  }

  if confirm "是否从 /v1/models 拉取模型列表？"; then
    while IFS= read -r model; do
      [[ -n "$model" ]] || continue
      models+=("$model")
    done < <(config_models "$profile")
  fi

  if ((${#models[@]} > 0)); then
    echo "请选择模型："
    for index in "${!models[@]}"; do
      printf '%s) %s\n' "$((index + 1))" "${models[$index]}"
    done
    echo "0) 手动输入"
    read -r -p "请输入选项编号: " selected || return 1
    if [[ "$selected" =~ ^[0-9]+$ ]] && ((selected >= 1 && selected <= ${#models[@]})); then
      model="${models[$((selected - 1))]}"
    else
      model="$(prompt_value "请输入模型名")" || return 1
    fi
  else
    warn "未获取到模型列表，改为手动输入。"
    model="$(prompt_value "请输入模型名")" || return 1
  fi

  replace_or_append_env "$file" "ANTHROPIC_MODEL" "$model"
  success "已更新 $profile 的 ANTHROPIC_MODEL=$model"
}

config_wrapper() {
  local profile="$1"
  local file
  local wrapper

  ensure_config_dirs
  file="$(profile_path "$profile")" || return 1
  [[ -f "$file" ]] || {
    error "profile 不存在：$profile"
    return 1
  }

  wrapper="$HOME/.local/bin/claude-$profile"
  cat > "$WRAPPERS_DIR/claude-$profile" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
set -a
source "$file"
set +a
exec claude "\$@"
EOF
  chmod +x "$WRAPPERS_DIR/claude-$profile"
  ln -sfn "$WRAPPERS_DIR/claude-$profile" "$wrapper"

  success "已生成 wrapper：$wrapper"
  info "确保 ~/.local/bin 在 PATH 中后，可执行：claude-$profile"
}

config_use() {
  local profile="$1"
  local file

  ensure_config_dirs
  file="$(profile_path "$profile")" || return 1
  [[ -f "$file" ]] || {
    error "profile 不存在：$profile"
    return 1
  }

  printf '%s\n' "$profile" > "$CONFIG_DIR/default"
  success "已设置默认 Claude Code profile：$profile"
  warn "默认 profile 只记录在 sh-tools 配置中，不会修改全局 shell 环境。"
}

config_show_menu() {
  echo "请选择 Claude Code 配置操作："
  echo ""
  echo "1) list - 列出 profiles"
  echo "2) add - 交互创建 profile"
  echo "3) status - 查看配置目录"
  echo "4) status <profile> - 查看 profile"
  echo "5) models <profile> - 从 /v1/models 拉取模型"
  echo "6) set-model <profile> - 选择或手动设置 ANTHROPIC_MODEL"
  echo "7) wrapper <profile> - 生成 claude-<profile>"
  echo "8) edit <profile> - 编辑 profile env"
  echo "9) use <profile> - 记录默认 profile"
  echo "0) 返回"
}

config_command() {
  local action="${1:-menu}"
  local profile="${2:-}"
  local choice

  case "$action" in
    menu)
      config_show_menu
      echo ""
      read -r -p "请输入选项编号: " choice || return 0
      case "$choice" in
        1) config_list ;;
        2) config_add ;;
        3) config_status ;;
        4) profile="$(prompt_value "请输入 profile 名称")" && config_status "$profile" ;;
        5) profile="$(prompt_value "请输入 profile 名称")" && config_models "$profile" ;;
        6) profile="$(prompt_value "请输入 profile 名称")" && config_set_model "$profile" ;;
        7) profile="$(prompt_value "请输入 profile 名称")" && config_wrapper "$profile" ;;
        8) profile="$(prompt_value "请输入 profile 名称")" && config_edit "$profile" ;;
        9) profile="$(prompt_value "请输入 profile 名称")" && config_use "$profile" ;;
        0) return 0 ;;
        *) error "输入无效。"; return 1 ;;
      esac
      ;;
    list)
      config_list
      ;;
    add)
      config_add
      ;;
    status)
      config_status "$profile"
      ;;
    edit)
      [[ -n "$profile" ]] || { error "请指定 profile。"; return 1; }
      config_edit "$profile"
      ;;
    models)
      [[ -n "$profile" ]] || { error "请指定 profile。"; return 1; }
      config_models "$profile"
      ;;
    set-model)
      [[ -n "$profile" ]] || { error "请指定 profile。"; return 1; }
      config_set_model "$profile"
      ;;
    wrapper)
      [[ -n "$profile" ]] || { error "请指定 profile。"; return 1; }
      config_wrapper "$profile"
      ;;
    use)
      [[ -n "$profile" ]] || { error "请指定 profile。"; return 1; }
      config_use "$profile"
      ;;
    *)
      error "未知 config 操作：$action"
      return 1
      ;;
  esac
}

run_method() {
  local action="$1"
  local method="$2"
  local action_label="安装"

  if [[ "$action" == "update" ]]; then
    action_label="更新"
  fi

  case "$method" in
    curl)
      require_commands curl bash || return 1
      warn_if_not_tty
      if [[ "$action" == "update" ]]; then
        info "将通过官方安装脚本更新 Claude Code 到最新版本："
      else
        info "将执行 Claude Code 官方安装脚本："
      fi
      print_command bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
      confirm "是否继续${action_label} Claude Code？" || return 0
      bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
      ;;
    npm)
      require_commands npm || return 1
      warn "官方 README 已标注 npm 安装方式为 deprecated。"
      if [[ "$action" == "update" ]]; then
        info "将通过 npm 更新 Claude Code 到最新版本："
      else
        info "将通过 npm 安装 Claude Code："
      fi
      print_command npm install -g @anthropic-ai/claude-code
      confirm "是否继续使用已弃用的 npm 方式${action_label} Claude Code？" || return 0
      npm install -g @anthropic-ai/claude-code
      ;;
    *)
      error "未知安装方式：$method"
      return 1
      ;;
  esac
}

doctor() {
  info "Claude Code 状态："
  report_binary_status "claude" "claude" || true
  report_binary_status "npm" "npm" || true
  report_binary_status "curl" "curl" || true
  report_env_status "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY"
  report_path_status "config dir" "$HOME/.claude"
}

remove_info() {
  info "Claude Code 卸载建议："
  echo "  npm 安装卸载："
  print_command npm uninstall -g @anthropic-ai/claude-code
  echo "  curl 安装通常需参考官方 setup 文档处理安装落点。"
  echo "  如需清理用户数据，可自行检查："
  print_command rm -rf "$HOME/.claude"
}

show_menu() {
  echo "请选择 Claude Code 操作："
  echo ""
  echo "1) install/curl - 官方安装脚本（推荐）"
  echo "2) install/npm - 全局安装（官方已标记为 deprecated）"
  echo "3) doctor - 检查安装状态"
  echo "4) update/curl - 用官方脚本更新"
  echo "5) update/npm - 用 npm 更新（deprecated）"
  echo "6) remove-info - 查看卸载建议"
  echo "7) config - 供应商 / 中转站 profile 管理"
  echo "0) 退出"
}

main() {
  local method="${1:-menu}"
  local choice

  case "$method" in
    menu)
      show_menu
      echo ""
      read -r -p "请输入选项编号: " choice || return 0
      case "$choice" in
        1) run_method install curl ;;
        2) run_method install npm ;;
        3) doctor ;;
        4) run_method update curl ;;
        5) run_method update npm ;;
        6) remove_info ;;
        7) config_command ;;
        0) return 0 ;;
        *) error "输入无效。"; return 1 ;;
      esac
      ;;
    list)
      printf '%s\n' "curl" "npm"
      ;;
    doctor)
      doctor
      ;;
    remove-info)
      remove_info
      ;;
    config)
      shift || true
      config_command "$@"
      ;;
    curl|npm)
      run_method install "$method"
      ;;
    update-curl)
      run_method update curl
      ;;
    update-npm)
      run_method update npm
      ;;
    -h|--help|help)
      printf '用法：\n'
      printf '  bash agents/providers/claude-code.sh [curl|npm|doctor|update-curl|update-npm|remove-info]\n'
      printf '  bash agents/providers/claude-code.sh config [list|add|status|edit|models|set-model|wrapper|use] [profile]\n'
      ;;
    *)
      error "未知参数：$method"
      return 1
      ;;
  esac
}

main "$@"
