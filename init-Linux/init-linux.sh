#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/shell-integration.sh" ]]; then
  source "$SCRIPT_DIR/../lib/shell-integration.sh"
fi

NVM_VERSION="v0.40.4"
APT_AVAILABLE=0

info() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
}

error() {
  printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
}

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
      else
        warn "$rc_file 不存在，已跳过。"
      fi
    done
  }
fi

if ! declare -F shell_append_line_if_missing >/dev/null 2>&1; then
  shell_append_line_if_missing() {
    local file="$1"
    local line="$2"

    if [[ ! -f "$file" ]]; then
      warn "$file 不存在，已跳过写入。"
      return 1
    fi

    if grep -Fxq "$line" "$file"; then
      return 0
    fi

    if ! printf '\n%s\n' "$line" >> "$file"; then
      error "写入 $file 失败。"
      return 1
    fi
  }
fi

if ! declare -F shell_source_current_rc >/dev/null 2>&1; then
  shell_source_current_rc() {
    local shell_name="${1:-$(basename "${SHELL:-}")}"
    local rc_file

    case "$shell_name" in
      bash) rc_file="$HOME/.bashrc" ;;
      zsh) rc_file="$HOME/.zshrc" ;;
      *)
        warn "当前 shell 为 ${shell_name:-未知}，已跳过自动 source，请重新打开终端。"
        return 0
        ;;
    esac

    if [[ ! -f "$rc_file" ]]; then
      warn "$rc_file 不存在，已跳过自动 source。"
      return 0
    fi

    if [[ "$shell_name" == "bash" ]]; then
      # shellcheck disable=SC1090
      source "$rc_file" || warn "source $rc_file 失败，请稍后手动 source 或重新打开终端。"
    else
      zsh -c 'source "$1"' _ "$rc_file" >/dev/null 2>&1 || warn "source $rc_file 失败，请稍后手动 source 或重新打开终端。"
    fi
  }
fi

confirm() {
  local prompt="${1:-是否继续？}"
  local answer

  read -r -p "${prompt} [y/N]: " answer || return 1
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

current_shell_name() {
  basename "${SHELL:-}"
}

check_apt_available() {
  command -v apt >/dev/null 2>&1
}

get_proxy_url() {
  printf '%s\n' "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-${ALL_PROXY:-${all_proxy:-}}}}}}"
}

run_with_git_proxy() {
  local proxy_url
  proxy_url="$(get_proxy_url)"

  if [[ -n "$proxy_url" ]]; then
    info "检测到代理环境变量，GitHub clone 将显式使用代理：$proxy_url"
    GIT_CONFIG_COUNT=2 \
      GIT_CONFIG_KEY_0=http.proxy \
      GIT_CONFIG_VALUE_0="$proxy_url" \
      GIT_CONFIG_KEY_1=https.proxy \
      GIT_CONFIG_VALUE_1="$proxy_url" \
      "$@"
  else
    "$@"
  fi
}

require_apt() {
  if check_apt_available; then
    APT_AVAILABLE=1
    return 0
  fi

  APT_AVAILABLE=0
  error "未检测到 apt，安装类操作已中止。当前脚本主要支持 Ubuntu / Debian / WSL Ubuntu。"
  return 1
}

check_system() {
  info "检测系统环境..."

  if check_apt_available; then
    APT_AVAILABLE=1
    success "已检测到 apt。"
  else
    APT_AVAILABLE=0
    warn "未检测到 apt。当前脚本主要支持 Ubuntu / Debian / WSL Ubuntu。"
  fi

  printf 'uname: %s\n' "$(uname -a)"
  if is_wsl; then
    printf 'WSL: 是\n'
  else
    printf 'WSL: 否\n'
  fi
  printf '当前 shell: %s\n' "${SHELL:-未知}"
  printf '当前用户: %s\n' "${USER:-$(id -un 2>/dev/null || printf '未知')}"
}

apt_update() {
  require_apt || return 1
  info "执行 sudo apt update..."
  sudo apt update
  success "apt 软件包索引已更新。"
}

install_deps() {
  require_apt || return 1

  local packages=(
    curl
    wget
    git
    ca-certificates
    unzip
    tar
    build-essential
  )
  local missing=()
  local pkg

  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if ((${#missing[@]} == 0)); then
    success "基础依赖已安装。"
    return 0
  fi

  warn "缺少基础依赖：${missing[*]}"
  if confirm "是否使用 apt 安装缺失依赖？"; then
    sudo apt install -y "${missing[@]}"
    success "基础依赖安装完成。"
  else
    warn "已跳过基础依赖安装。"
  fi
}

setup_mirror() {
  require_apt || return 1

  if ! command -v curl >/dev/null 2>&1; then
    error "未检测到 curl，请先执行 deps 安装基础依赖。"
    return 1
  fi

  warn "即将启动 linuxmirror 交互式脚本。"
  info "一般建议：选择清华大学源，使用 HTTP，不更新软件包。"
  if confirm "是否继续配置软件源？"; then
    bash <(curl -sSL https://linuxmirrors.cn/main.sh)
    success "linuxmirror 脚本已执行结束。"
  else
    warn "已跳过软件源配置。"
  fi
}

install_zsh() {
  require_apt || return 1

  if command -v zsh >/dev/null 2>&1; then
    success "zsh 已安装：$(command -v zsh)"
  else
    info "安装 zsh..."
    sudo apt install -y zsh
    success "zsh 安装完成。"
  fi

  info '如需切换默认 shell，可手动执行：chsh -s "$(command -v zsh)"'
}

install_oh_my_zsh() {
  if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    success "Oh My Zsh 已安装，跳过。"
    return 0
  fi

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    error "~/.oh-my-zsh 已存在，但未检测到 oh-my-zsh.sh，可能是上次安装中断留下的半成品。"
    warn "请手动检查并处理该目录后再执行 ohmyzsh，脚本不会自动删除用户文件。"
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    error "未检测到 curl，请先执行 deps 安装基础依赖。"
    return 1
  fi

  if [[ "$(current_shell_name)" != "zsh" ]]; then
    warn "当前 shell 不是 zsh，仍可安装 Oh My Zsh；脚本不会自动切换默认 shell。"
  fi

  info "安装 Oh My Zsh..."
  run_with_git_proxy env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://install.ohmyz.sh)"
  success "Oh My Zsh 安装完成。"
}

install_powerlevel10k() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    warn "未检测到 Oh My Zsh，请先执行 ohmyzsh。"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    error "未检测到 git，请先执行 deps 安装基础依赖。"
    return 1
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local theme_dir="$zsh_custom/themes/powerlevel10k"

  if [[ -d "$theme_dir" ]]; then
    success "Powerlevel10k 已存在，跳过 clone。"
  else
    info "安装 Powerlevel10k..."
    mkdir -p "$(dirname "$theme_dir")"
    run_with_git_proxy git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
    success "Powerlevel10k 安装完成。"
  fi

  configure_p10k_theme
}

configure_p10k_theme() {
  local zshrc="$HOME/.zshrc"

  if [[ ! -f "$zshrc" ]]; then
    warn "~/.zshrc 不存在，已跳过 Powerlevel10k 主题配置。"
    return 0
  fi

  if grep -Eq '^[[:space:]]*ZSH_THEME=' "$zshrc"; then
    if grep -Eq '^[[:space:]]*ZSH_THEME="powerlevel10k/powerlevel10k"' "$zshrc"; then
      success "~/.zshrc 已配置 Powerlevel10k 主题。"
    else
      info "更新 ~/.zshrc 中的 ZSH_THEME..."
      sed -i.bak 's|^[[:space:]]*ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"
      success "Powerlevel10k 主题配置已更新，原文件备份为 ~/.zshrc.bak。"
    fi
  else
    printf '\nZSH_THEME="powerlevel10k/powerlevel10k"\n' >> "$zshrc"
    success "已向 ~/.zshrc 追加 Powerlevel10k 主题配置。"
  fi
}

ensure_block_in_file() {
  local file="$1"
  local marker="$2"
  local block="$3"

  if [[ ! -f "$file" ]]; then
    warn "$file 不存在，已跳过写入。"
    return 1
  fi

  if grep -Fq "$marker" "$file"; then
    return 0
  fi

  if ! printf '\n%s\n' "$block" >> "$file"; then
    error "写入 $file 失败。"
    return 1
  fi
}

ensure_nvm_env_in_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    warn "$file 不存在，已跳过写入。"
    return 1
  fi

  if ! grep -Eq '^[[:space:]]*export[[:space:]]+NVM_DIR="\$HOME/\.nvm"' "$file"; then
    if ! printf '\n%s\n' 'export NVM_DIR="$HOME/.nvm"' >> "$file"; then
      error "写入 $file 失败。"
      return 1
    fi
  fi

  if ! grep -Eq '^[[:space:]]*\[[[:space:]]+-s[[:space:]]+"\$NVM_DIR/nvm\.sh"[[:space:]]+\][[:space:]]+&&[[:space:]]+\\?\.[[:space:]]+"\$NVM_DIR/nvm\.sh"' "$file"; then
    if ! printf '%s\n' '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$file"; then
      error "写入 $file 失败。"
      return 1
    fi
  fi

  if ! grep -Eq '^[[:space:]]*\[[[:space:]]+-s[[:space:]]+"\$NVM_DIR/bash_completion"[[:space:]]+\][[:space:]]+&&[[:space:]]+\\?\.[[:space:]]+"\$NVM_DIR/bash_completion"' "$file"; then
    if ! printf '%s\n' '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> "$file"; then
      error "写入 $file 失败。"
      return 1
    fi
  fi
}

fix_shell_env() {
  local rc_file
  local rc_files=()
  local nvm_installed=0
  local uv_installed=0

  while IFS= read -r rc_file; do
    rc_files+=("$rc_file")
  done < <(shell_rc_files)

  if ((${#rc_files[@]} == 0)); then
    warn "未检测到 ~/.bashrc 或 ~/.zshrc，已跳过环境变量修复。"
    return 0
  fi

  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    nvm_installed=1
  else
    warn "未检测到 $HOME/.nvm/nvm.sh，跳过 nvm 环境变量。"
  fi

  if [[ -x "$HOME/.local/bin/uv" ]] || command -v uv >/dev/null 2>&1; then
    uv_installed=1
  else
    warn "未检测到 uv，跳过 uv PATH。"
  fi

  if ((nvm_installed == 0 && uv_installed == 0)); then
    warn "未检测到 nvm 或 uv，已跳过环境变量修复。"
    return 0
  fi

  for rc_file in "${rc_files[@]}"; do
    info "修复 shell 配置文件：$rc_file"

    if ((nvm_installed == 1)); then
      if ensure_nvm_env_in_file "$rc_file"; then
        success "$rc_file 中的 nvm 环境变量已检查。"
      else
        warn "$rc_file 中的 nvm 环境变量修复未完成。"
      fi
    fi

    if ((uv_installed == 1)); then
      if shell_append_line_if_missing "$rc_file" 'export PATH="$HOME/.local/bin:$PATH"'; then
        success "$rc_file 中的 uv PATH 已检查。"
      else
        warn "$rc_file 中的 uv PATH 修复未完成。"
      fi
    fi
  done

  shell_source_current_rc "$(current_shell_name)"
}

load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
}

install_nvm() {
  if ! command -v curl >/dev/null 2>&1; then
    error "未检测到 curl，请先执行 deps 安装基础依赖。"
    return 1
  fi

  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    success "nvm 已安装，跳过安装脚本。"
  else
    info "安装 nvm ${NVM_VERSION}..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    success "nvm 安装脚本已执行。"
  fi

  fix_shell_env
  load_nvm

  if command -v nvm >/dev/null 2>&1; then
    success "nvm 当前可用。"
  else
    warn "nvm 尚未在当前进程可用，请重新打开终端后再试。"
  fi
}

install_node_lts() {
  load_nvm

  if ! command -v nvm >/dev/null 2>&1; then
    error "nvm 不可用，请先执行 nvm。"
    return 1
  fi

  info "安装 Node.js LTS 并设置为 default..."
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default

  node -v
  npm -v
  success "Node.js LTS 已安装并设为默认版本。"
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    success "uv 已安装：$(uv --version)"
    fix_shell_env
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    error "未检测到 curl，请先执行 deps 安装基础依赖。"
    return 1
  fi

  info "安装 uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh

  export PATH="$HOME/.local/bin:$PATH"
  fix_shell_env

  if command -v uv >/dev/null 2>&1; then
    uv --version
    success "uv 安装完成。"
  else
    warn "uv 安装后当前进程仍不可用，请重新打开终端后再试。"
  fi
}

print_finish_message() {
  local shell_name
  shell_name="$(current_shell_name)"

  printf '\n初始化流程已完成。\n\n'
  printf '如果你安装了 zsh，但尚未切换默认 shell，可以手动执行：\n'
  printf 'chsh -s "$(command -v zsh)"\n\n'

  printf '如果刚安装了 nvm / uv，但当前终端无法识别命令，请重新打开终端'
  case "$shell_name" in
    bash)
      printf '，或执行：\nsource ~/.bashrc\n'
      ;;
    zsh)
      printf '，或执行：\nsource ~/.zshrc\n'
      ;;
    *)
      printf '。\n'
      ;;
  esac
}

run_all() {
  check_system
  require_apt || return 1
  setup_mirror
  apt_update
  install_deps
  install_zsh
  install_oh_my_zsh
  install_powerlevel10k
  install_nvm
  install_node_lts
  install_uv
  fix_shell_env
  print_finish_message
}

show_menu() {
  cat <<'MENU'
请选择要执行的操作：

1) 检测系统环境
2) 配置软件源
3) 检查并安装基础依赖
4) 安装 zsh
5) 安装 Oh My Zsh
6) 安装 Powerlevel10k
7) 安装 nvm
8) 安装 Node.js LTS
9) 安装 uv
10) 修复 nvm / uv 环境变量
11) 一键安装全部
0) 退出
MENU
}

interactive_menu() {
  local choice

  while true; do
    printf '\n'
    show_menu
    read -r -p "请输入选项编号: " choice || return 0

    case "$choice" in
      1) check_system ;;
      2) setup_mirror ;;
      3) install_deps ;;
      4) install_zsh ;;
      5) install_oh_my_zsh ;;
      6) install_powerlevel10k ;;
      7) install_nvm ;;
      8) install_node_lts ;;
      9) install_uv ;;
      10) fix_shell_env ;;
      11) run_all ;;
      0) success "已退出。"; return 0 ;;
      *) warn "无效选项，请输入 0-11。" ;;
    esac
  done
}

usage() {
  cat <<'USAGE'
用法：
  bash init-ubuntu.sh
  bash init-ubuntu.sh all
  bash init-ubuntu.sh check
  bash init-ubuntu.sh mirror
  bash init-ubuntu.sh deps
  bash init-ubuntu.sh zsh
  bash init-ubuntu.sh ohmyzsh
  bash init-ubuntu.sh p10k
  bash init-ubuntu.sh nvm
  bash init-ubuntu.sh node
  bash init-ubuntu.sh uv
  bash init-ubuntu.sh env
USAGE
}

main() {
  local command="${1:-menu}"

  case "$command" in
    menu) interactive_menu ;;
    all) run_all ;;
    check) check_system ;;
    mirror) setup_mirror ;;
    deps) install_deps ;;
    zsh) install_zsh ;;
    ohmyzsh) install_oh_my_zsh ;;
    p10k) install_powerlevel10k ;;
    nvm) install_nvm ;;
    node) install_node_lts ;;
    uv) install_uv ;;
    env) fix_shell_env ;;
    -h|--help|help) usage ;;
    *)
      error "未知参数：$command"
      usage
      return 1
      ;;
  esac
}

main "$@"
