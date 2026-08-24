#!/usr/bin/env bash
set -Eeuo pipefail

NVM_VERSION="v0.40.4"
APT_AVAILABLE=0

CORE_DEP_PACKAGES=(
  curl
  ca-certificates
  git
  tar
  xz-utils
)

RECOMMENDED_DEP_PACKAGES=(
  openssh-client
  wget
  unzip
  file
  less
)

BUILD_DEP_PACKAGES=(
  build-essential
  pkg-config
  python3-dev
)

DIAGNOSE_DEP_PACKAGES=(
  lsof
  dnsutils
  netcat-openbsd
  rsync
)

AGENT_TOOL_PACKAGES=(
  ripgrep
  jq
  tmux
)

AGENT_TOOL_ENHANCEMENT_PACKAGES=(
  fzf
  tree
  zip
)

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

confirm() {
  local prompt="${1:-是否继续？}"
  local answer

  read -r -p "${prompt} [y/N]: " answer || return 1
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
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

is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

check_apt_available() {
  command -v apt >/dev/null 2>&1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_status_line() {
  local label="$1"
  local status="$2"
  local details="${3:-}"

  if [[ -n "$details" ]]; then
    printf '  %-20s %-8s %s\n' "$label" "$status" "$details"
  else
    printf '  %-20s %s\n' "$label" "$status"
  fi
}

report_command_status() {
  local label="$1"
  local command_name="$2"

  if command_exists "$command_name"; then
    local version
    version="$("$command_name" --version 2>/dev/null | head -n 1 || true)"
    if [[ -n "$version" ]]; then
      print_status_line "$label" "OK" "$version"
    else
      print_status_line "$label" "OK" "$(command -v "$command_name")"
    fi
  else
    print_status_line "$label" "MISSING"
  fi
}

report_file_status() {
  local label="$1"
  local path="$2"

  if [[ -e "$path" ]]; then
    print_status_line "$label" "OK" "$path"
  else
    print_status_line "$label" "MISSING" "$path"
  fi
}

report_config_status() {
  local label="$1"
  local status="$2"
  local details="${3:-}"

  print_status_line "$label" "$status" "$details"
}

rc_has_nvm_env() {
  local file="$1"

  [[ -f "$file" ]] || return 1
  grep -Eq '^[[:space:]]*export[[:space:]]+NVM_DIR="\$HOME/\.nvm"' "$file" &&
    grep -Eq '^[[:space:]]*\[[[:space:]]+-s[[:space:]]+"\$NVM_DIR/nvm\.sh"[[:space:]]+\][[:space:]]+&&[[:space:]]+\\?\.[[:space:]]+"\$NVM_DIR/nvm\.sh"' "$file" &&
    grep -Eq '^[[:space:]]*\[[[:space:]]+-s[[:space:]]+"\$NVM_DIR/bash_completion"[[:space:]]+\][[:space:]]+&&[[:space:]]+\\?\.[[:space:]]+"\$NVM_DIR/bash_completion"' "$file"
}

rc_has_uv_path() {
  local file="$1"

  [[ -f "$file" ]] || return 1
  grep -Fxq 'export PATH="$HOME/.local/bin:$PATH"' "$file"
}

check_shell_rc_config() {
  local rc_file
  local found=0
  local rc_files=(
    "$HOME/.bashrc"
  )

  echo "Shell rc 配置:"
  for rc_file in "${rc_files[@]}"; do
    [[ -f "$rc_file" ]] || continue
    found=1

    if rc_has_nvm_env "$rc_file"; then
      report_config_status "$(basename "$rc_file") nvm" "OK"
    else
      report_config_status "$(basename "$rc_file") nvm" "MISSING"
    fi

    if rc_has_uv_path "$rc_file"; then
      report_config_status "$(basename "$rc_file") uv PATH" "OK"
    else
      report_config_status "$(basename "$rc_file") uv PATH" "MISSING"
    fi
  done

  if ((found == 0)); then
    print_status_line "rc files" "MISSING" "~/.bashrc"
  fi
}

check_node_stack() {
  echo "Node 栈:"
  report_file_status "nvm" "$HOME/.nvm/nvm.sh"
  report_command_status "node" "node"
  report_command_status "npm" "npm"
  report_command_status "corepack" "corepack"
  report_command_status "pnpm" "pnpm"
}

check_python_stack() {
  echo "Python / uv:"
  report_command_status "python3" "python3"
  report_command_status "pip3" "pip3"
  report_command_status "uv" "uv"
}

check_wsl_config_status() {
  local wsl_conf="/etc/wsl.conf"

  echo "WSL 状态:"
  if is_wsl; then
    print_status_line "environment" "OK" "WSL"
  else
    print_status_line "environment" "MISSING" "非 WSL 环境"
    return 0
  fi

  if [[ -f "$wsl_conf" ]]; then
    report_file_status "wsl.conf" "$wsl_conf"
    if grep -Eq '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true' "$wsl_conf"; then
      report_config_status "metadata" "OK"
    else
      report_config_status "metadata" "MISSING"
    fi
  else
    report_file_status "wsl.conf" "$wsl_conf"
    report_config_status "metadata" "MISSING"
  fi

  echo "建议："
  echo "  1. 开发项目尽量放在 Linux 文件系统内，例如 ~/code"
  echo "  2. 如需更好的文件权限兼容性，可考虑在 /etc/wsl.conf 中启用 metadata"
  echo "  3. 修改 /etc/wsl.conf 后，通常需要执行 wsl --shutdown 再重新进入发行版"
}

check_agenttools_status() {
  echo "Agent 工具:"
  report_command_status "rg" "rg"
  report_command_status "jq" "jq"
  report_command_status "tmux" "tmux"

  echo "Agent 可选增强:"
  report_command_status "fzf" "fzf"
  report_command_status "tree" "tree"
  report_command_status "zip" "zip"
}

check_core_tools_status() {
  echo "核心工具:"
  report_command_status "curl" "curl"
  report_command_status "wget" "wget"
  report_command_status "git" "git"
  report_command_status "ssh-keygen" "ssh-keygen"
}

check_privilege_status() {
  if ((EUID == 0)); then
    print_status_line "管理员权限" "OK" "root"
  elif command -v sudo >/dev/null 2>&1; then
    print_status_line "管理员权限" "OK" "sudo"
  else
    print_status_line "管理员权限" "MISSING" "需要 root 或 sudo 才能安装软件包"
  fi
}

get_proxy_url() {
  printf '%s\n' "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-${ALL_PROXY:-${all_proxy:-}}}}}}"
}

require_curl() {
  if ! command -v curl >/dev/null 2>&1; then
    error "未检测到 curl，请先执行 deps 安装基础依赖。"
    return 1
  fi
}

print_proxy_guidance() {
  local proxy_url
  proxy_url="$(get_proxy_url)"

  if [[ -n "$proxy_url" ]]; then
    warn "已检测到代理环境变量：$proxy_url，请检查代理是否可用。"
  else
    warn "当前未检测到代理环境变量；如下载失败，可先配置代理后重试。"
  fi
}

download_to_file() {
  local url="$1"
  local destination="$2"
  local label="$3"

  require_curl || return 1

  if [[ -n "$(get_proxy_url)" ]]; then
    info "$label 将使用当前代理环境下载。"
  fi

  if curl -fsSL "$url" -o "$destination"; then
    return 0
  fi

  error "$label 下载失败：$url"
  print_proxy_guidance
  return 1
}

require_apt() {
  if check_apt_available; then
    APT_AVAILABLE=1
    return 0
  fi

  APT_AVAILABLE=0
  error "未检测到 apt，安装类操作已中止。当前脚本主要支持 Debian 系发行版（如 Ubuntu、Debian、Linux Mint、Pop!_OS、Kali），并提供 WSL 可选增强。"
  return 1
}

run_as_root() {
  if ((EUID == 0)); then
    "$@"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return 0
  fi

  error "当前用户不是 root，且未检测到 sudo，无法执行需要管理员权限的操作。"
  return 1
}

run_apt() {
  run_as_root apt "$@"
}

check_system() {
  info "检测系统环境..."

  if check_apt_available; then
    APT_AVAILABLE=1
    success "已检测到 apt。"
  else
    APT_AVAILABLE=0
    warn "未检测到 apt。当前脚本主要支持 Debian 系发行版（如 Ubuntu、Debian、Linux Mint、Pop!_OS、Kali），并提供 WSL 可选增强。"
  fi

  printf 'uname: %s\n' "$(uname -a)"
  if is_wsl; then
    printf 'WSL: 是\n'
  else
    printf 'WSL: 否\n'
  fi
  printf '当前 shell: %s\n' "${SHELL:-未知}"
  printf '当前用户: %s\n' "${USER:-$(id -un 2>/dev/null || printf '未知')}"
  printf '代理环境: %s\n' "$(get_proxy_url | sed 's/^$/未设置/')"
  echo

  check_core_tools_status
  echo
  check_privilege_status
  echo
  check_agenttools_status
  echo
  check_node_stack
  echo
  check_python_stack
  echo
  check_wsl_config_status
  echo
  check_shell_rc_config
}

apt_update() {
  require_apt || return 1
  info "执行 apt update..."
  run_apt update
  success "apt 软件包索引已更新。"
}

get_missing_packages() {
  local package

  for package in "$@"; do
    if ! dpkg -s "$package" >/dev/null 2>&1; then
      printf '%s\n' "$package"
    fi
  done
}

install_package_group() {
  local label="$1"
  local required="$2"
  shift 2

  local missing=()
  local package

  while IFS= read -r package; do
    missing+=("$package")
  done < <(get_missing_packages "$@")

  if ((${#missing[@]} == 0)); then
    success "$label 已安装。"
    return 0
  fi

  warn "缺少$label：${missing[*]}"
  if [[ "$required" != "required" ]] && ! confirm "是否使用 apt 安装缺失的$label？"; then
    warn "已跳过$label。"
    return 0
  fi

  run_apt install -y "${missing[@]}"
  success "$label 安装完成。"
}

install_core_deps() {
  require_apt || return 1
  install_package_group "核心必需依赖" "required" "${CORE_DEP_PACKAGES[@]}"
}

install_recommended_deps() {
  require_apt || return 1
  install_package_group "推荐依赖" "recommended" "${RECOMMENDED_DEP_PACKAGES[@]}"
}

install_build_deps() {
  local required="${1:-optional}"

  require_apt || return 1
  install_package_group "编译扩展依赖" "$required" "${BUILD_DEP_PACKAGES[@]}"
}

install_diagnose_deps() {
  local required="${1:-optional}"

  require_apt || return 1
  install_package_group "诊断与同步依赖" "$required" "${DIAGNOSE_DEP_PACKAGES[@]}"
}

install_optional_deps() {
  local choice

  if ! confirm "是否选择安装可选依赖组？"; then
    info "已跳过可选依赖组。"
    return 0
  fi

  cat <<'MENU'
请选择可选依赖组：
1) 编译扩展（build-essential、pkg-config、python3-dev）
2) 诊断与同步（lsof、dnsutils、netcat-openbsd、rsync）
3) 两组都安装
0) 跳过
MENU
  read -r -p "请输入选项编号: " choice || return 0

  case "$choice" in
    1) install_build_deps required ;;
    2) install_diagnose_deps required ;;
    3)
      install_build_deps required
      install_diagnose_deps required
      ;;
    0) info "已跳过可选依赖组。" ;;
    *) warn "无效选项，已跳过可选依赖组。" ;;
  esac
}

install_deps() {
  local mode="${1:-interactive}"

  case "$mode" in
    interactive)
      install_core_deps || return 1
      install_recommended_deps || return 1
      install_optional_deps
      ;;
    build) install_build_deps ;;
    diagnose) install_diagnose_deps ;;
    *)
      error "未知 deps 选项：$mode"
      return 1
      ;;
  esac
}

install_agenttools() {
  require_apt || return 1

  install_package_group "Agent 核心工具" "recommended" "${AGENT_TOOL_PACKAGES[@]}" || return 1

  if confirm "是否安装 Agent 可选增强工具？"; then
    install_package_group "Agent 可选增强工具" "required" "${AGENT_TOOL_ENHANCEMENT_PACKAGES[@]}"
  else
    info "已跳过 Agent 可选增强工具。"
  fi
}

install_devtools_compat() {
  warn "devtools 已更名为 agenttools，正在按兼容模式执行。"
  install_agenttools
}

gitcfg_set_value() {
  local key="$1"
  local prompt="$2"
  local current_value="$3"
  local suggested_default="${4:-}"
  local target_value=""

  if [[ -n "$current_value" ]]; then
    info "$key 当前值：$current_value"
    if ! confirm "是否更新 $key？"; then
      info "保留 $key 当前值。"
      return 0
    fi
    target_value="$(prompt_value "$prompt" "$current_value")" || return 1
  else
    target_value="$(prompt_value "$prompt" "$suggested_default")" || return 1
  fi

  if [[ -z "$target_value" ]]; then
    warn "$key 未设置，已跳过。"
    return 0
  fi

  git config --global "$key" "$target_value"
  success "已设置 $key=$target_value"
}

configure_git() {
  if ! command -v git >/dev/null 2>&1; then
    error "未检测到 git，请先执行 deps 安装基础依赖。"
    return 1
  fi

  info "当前 Git 全局配置："
  printf '  user.name: %s\n' "$(git config --global --get user.name || printf '未设置')"
  printf '  user.email: %s\n' "$(git config --global --get user.email || printf '未设置')"
  printf '  init.defaultBranch: %s\n' "$(git config --global --get init.defaultBranch || printf '未设置')"
  printf '  core.editor: %s\n' "$(git config --global --get core.editor || printf '未设置')"

  gitcfg_set_value "user.name" "请输入 Git 用户名" "$(git config --global --get user.name || true)" || return 1
  gitcfg_set_value "user.email" "请输入 Git 邮箱" "$(git config --global --get user.email || true)" || return 1
  gitcfg_set_value "init.defaultBranch" "请输入默认分支名" "$(git config --global --get init.defaultBranch || true)" "main" || return 1
  gitcfg_set_value "core.editor" "请输入默认编辑器" "$(git config --global --get core.editor || true)" "vim" || return 1
}

setup_mirror() {
  require_apt || return 1
  require_curl || return 1

  warn "即将启动 linuxmirror 交互式脚本。"
  info "一般建议：选择清华大学源，使用 HTTP，不更新软件包。"
  if confirm "是否继续配置软件源？"; then
    local script_file
    script_file="$(mktemp)"
    trap 'rm -f "$script_file"' RETURN
    download_to_file "https://linuxmirrors.cn/main.sh" "$script_file" "linuxmirror 脚本" || return 1
    info "linuxmirror 需要 root 权限，接下来会使用 root 或 sudo 执行。"
    run_as_root bash "$script_file"
    rm -f "$script_file"
    trap - RETURN
    success "linuxmirror 脚本已执行结束。"
  else
    warn "已跳过软件源配置。"
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
    warn "未检测到 ~/.bashrc，已跳过环境变量修复。"
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

  info "环境变量已写入 ~/.bashrc；请重新打开终端或手动执行 source ~/.bashrc 生效。"
}

load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    . "$NVM_DIR/nvm.sh"
  fi
}

install_nvm() {
  require_curl || return 1

  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    success "nvm 已安装，跳过安装脚本。"
  else
    info "安装 nvm ${NVM_VERSION}..."
    local script_file
    script_file="$(mktemp)"
    trap 'rm -f "$script_file"' RETURN
    download_to_file "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" "$script_file" "nvm 安装脚本" || return 1
    bash "$script_file"
    rm -f "$script_file"
    trap - RETURN
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

configure_node_tools() {
  load_nvm

  if ! command -v node >/dev/null 2>&1; then
    error "node 不可用，请先执行 node 安装 Node.js LTS。"
    return 1
  fi

  if ! command -v corepack >/dev/null 2>&1; then
    error "未检测到 corepack；请先确认当前 Node.js 版本是否自带 corepack。"
    return 1
  fi

  info "启用 corepack..."
  corepack enable
  success "corepack 已启用。"

  if confirm "是否激活 pnpm？"; then
    info "准备激活 pnpm..."
    corepack prepare pnpm@latest --activate
    success "pnpm 已激活。"
  else
    warn "已跳过 pnpm 激活。"
  fi

  echo "Node 工具状态："
  node -v
  npm -v
  if command -v corepack >/dev/null 2>&1; then
    corepack --version | head -n 1
  fi
  if command -v pnpm >/dev/null 2>&1; then
    pnpm --version
  else
    warn "pnpm 当前不可用。"
  fi
}

install_python_tools() {
  require_apt || return 1

  local packages=(
    python3
    python3-pip
    python3-venv
  )
  local missing=()
  local pkg

  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if ((${#missing[@]} == 0)); then
    success "Python 开发工具已安装。"
  else
    warn "缺少 Python 开发工具：${missing[*]}"
    if confirm "是否使用 apt 安装缺失的 Python 开发工具？"; then
      run_apt install -y "${missing[@]}"
      success "Python 开发工具安装完成。"
    else
      warn "已跳过 Python 开发工具安装。"
      return 0
    fi
  fi

  echo "Python 工具状态："
  if command -v python3 >/dev/null 2>&1; then
    python3 --version
  fi
  if command -v pip3 >/dev/null 2>&1; then
    pip3 --version | head -n 1
  fi
  python3 -m venv --help >/dev/null 2>&1 && success "python3-venv 当前可用。"
}

init_ssh() {
  local ssh_dir="$HOME/.ssh"
  local private_key="$ssh_dir/id_ed25519"
  local public_key="${private_key}.pub"
  local email_hint=""

  if ! command -v ssh-keygen >/dev/null 2>&1; then
    warn "未检测到 ssh-keygen。"
    if confirm "是否安装 openssh-client？"; then
      require_apt || return 1
      run_apt install -y openssh-client
    else
      warn "已跳过 openssh-client 安装，无法初始化 SSH key。"
      return 1
    fi

    if ! command -v ssh-keygen >/dev/null 2>&1; then
      error "openssh-client 安装后仍未检测到 ssh-keygen。"
      return 1
    fi
  fi

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ -f "$private_key" && -f "$public_key" ]]; then
    info "已检测到现有 SSH key，跳过生成。"
  else
    email_hint="$(git config --global --get user.email || true)"
    info "准备生成 ed25519 SSH key..."
    if [[ -n "$email_hint" ]]; then
      ssh-keygen -t ed25519 -C "$email_hint" -N "" -f "$private_key"
    else
      ssh-keygen -t ed25519 -N "" -f "$private_key"
    fi
    success "SSH key 已生成。"
  fi

  chmod 600 "$private_key"
  chmod 644 "$public_key"

  echo "SSH 状态："
  printf '  私钥: %s\n' "$private_key"
  printf '  公钥: %s\n' "$public_key"
  echo "下一步："
  echo "  1. 将公钥内容添加到 GitHub / GitLab / 服务器"
  echo "  2. 如需加载到 agent，可执行：ssh-add $private_key"
  echo "公钥内容："
  cat "$public_key"
}

show_wsl_advice() {
  check_wsl_config_status
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    success "uv 已安装：$(uv --version)"
    fix_shell_env
    return 0
  fi

  require_curl || return 1

  info "安装 uv..."
  local script_file
  script_file="$(mktemp)"
  trap 'rm -f "$script_file"' RETURN
  download_to_file "https://astral.sh/uv/install.sh" "$script_file" "uv 安装脚本" || return 1
  sh "$script_file"
  rm -f "$script_file"
  trap - RETURN

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
  printf '\n初始化流程已完成。\n\n'
  printf '如果刚安装了 nvm / uv，但当前终端无法识别命令，请重新打开终端，或执行：\n'
  printf 'source ~/.bashrc\n'
}

run_all() {
  check_system
  require_apt || return 1
  apt_update
  install_core_deps
  install_recommended_deps
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
3) 检查并安装依赖（核心、推荐、可选）
4) 安装 Agent 工具包（检索、数据、会话）
5) 初始化 Git 全局配置
6) 安装 nvm
7) 安装 Node.js LTS
8) 配置 Node 工具链（corepack / pnpm）
9) 安装 Python 开发工具
10) 初始化 SSH key
11) 查看 WSL 状态与建议
12) 安装 uv
13) 修复 nvm / uv 环境变量
14) 一键安装全部
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
      4) install_agenttools ;;
      5) configure_git ;;
      6) install_nvm ;;
      7) install_node_lts ;;
      8) configure_node_tools ;;
      9) install_python_tools ;;
      10) init_ssh ;;
      11) show_wsl_advice ;;
      12) install_uv ;;
      13) fix_shell_env ;;
      14) run_all ;;
      0) success "已退出。"; return 0 ;;
      *) warn "无效选项，请输入 0-14。" ;;
    esac
  done
}

usage() {
  cat <<'USAGE'
用法：
  bash init-linux.sh
  bash init-linux.sh all
  bash init-linux.sh check
  bash init-linux.sh mirror
  bash init-linux.sh deps
  bash init-linux.sh deps build
  bash init-linux.sh deps diagnose
  bash init-linux.sh agenttools
  bash init-linux.sh devtools  # 兼容别名
  bash init-linux.sh gitcfg
  bash init-linux.sh nvm
  bash init-linux.sh node
  bash init-linux.sh nodetools
  bash init-linux.sh pytools
  bash init-linux.sh ssh-init
  bash init-linux.sh wsl
  bash init-linux.sh uv
  bash init-linux.sh env
USAGE
}

main() {
  local command="${1:-menu}"

  case "$command" in
    menu) interactive_menu ;;
    all) run_all ;;
    check) check_system ;;
    mirror) setup_mirror ;;
    deps) install_deps "${2:-interactive}" ;;
    agenttools) install_agenttools ;;
    devtools) install_devtools_compat ;;
    gitcfg) configure_git ;;
    nvm) install_nvm ;;
    node) install_node_lts ;;
    nodetools) configure_node_tools ;;
    pytools) install_python_tools ;;
    ssh-init) init_ssh ;;
    wsl) show_wsl_advice ;;
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
