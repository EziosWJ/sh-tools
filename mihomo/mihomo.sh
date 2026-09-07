#!/usr/bin/env bash
set -Eeuo pipefail

# Mihomo TUN 部署与 systemd 管理工具。
# 只支持真实 Linux + systemd；不会修改 Docker daemon 或启用开机自启动。

MIHOMO_VERSION="${MIHOMO_VERSION:-v1.19.30}"
MIHOMO_BINARY="${MIHOMO_BINARY:-/usr/local/bin/mihomo}"
MIHOMO_BINARY_SOURCE_DIR="${MIHOMO_BINARY_SOURCE_DIR:-/opt}"
MIHOMO_CONFIG_DIR="${MIHOMO_CONFIG_DIR:-/etc/mihomo}"
MIHOMO_CONFIG="${MIHOMO_CONFIG:-$MIHOMO_CONFIG_DIR/config.yaml}"
MIHOMO_SERVICE="${MIHOMO_SERVICE:-/etc/systemd/system/mihomo.service}"
MIHOMO_DOWNLOAD_BASE="${MIHOMO_DOWNLOAD_BASE:-https://github.com/MetaCubeX/mihomo/releases/download}"
MIHOMO_GITHUB_API="${MIHOMO_GITHUB_API:-https://api.github.com/repos/MetaCubeX/mihomo/releases/tags}"
MIHOMO_UPSTREAM_SERVER_INPUT="${MIHOMO_UPSTREAM_SERVER-}"
MIHOMO_UPSTREAM_PORT_INPUT="${MIHOMO_UPSTREAM_PORT-}"
MIHOMO_CONTROLLER_ADDRESS_INPUT="${MIHOMO_CONTROLLER_ADDRESS-}"
MIHOMO_UPSTREAM_SERVER="${MIHOMO_UPSTREAM_SERVER:-192.168.1.32}"
MIHOMO_UPSTREAM_PORT="${MIHOMO_UPSTREAM_PORT:-7897}"
MIHOMO_CONTROLLER_ADDRESS="${MIHOMO_CONTROLLER_ADDRESS:-}"
MIHOMO_SECRET="${MIHOMO_SECRET:-}"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[1;34m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; RESET=''
fi

info() { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
success() { printf '%s[SUCCESS]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2; }

usage() {
  cat <<'EOF'
Mihomo TUN 工具

用法：
  bash mihomo.sh                 进入交互菜单
  bash mihomo.sh setup           生成配置、注册并启动 systemd 服务
  bash mihomo.sh download        可选下载并安装 Mihomo 二进制
  bash mihomo.sh install-local   从本地文件安装二进制
  bash mihomo.sh start|stop|restart|status|show-config|logs
  bash mihomo.sh uninstall       停止服务并移除本工具创建的资源

可覆盖的环境变量：
  MIHOMO_VERSION                 默认 v1.19.30
  MIHOMO_UPSTREAM_SERVER         默认 192.168.1.32
  MIHOMO_UPSTREAM_PORT           默认 7897
  MIHOMO_CONTROLLER_ADDRESS      默认自动检测本机 IPv4
  MIHOMO_SECRET                  默认复用已有值或生成随机值
  MIHOMO_BINARY_SOURCE_DIR       默认从 /opt 查找手动下载的二进制
EOF
}

confirm() {
  local prompt="$1" answer
  read -r -p "$prompt [y/N]: " answer || return 1
  [[ "$answer" =~ ^([yY][eE][sS]|[yY])$ ]]
}

run_privileged_subcommand() {
  local subcommand="$1"
  shift || true
  if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || {
      error "此操作需要 root 权限，且未找到 sudo。"
      return 1
    }
    sudo --preserve-env=MIHOMO_VERSION,MIHOMO_BINARY,MIHOMO_BINARY_SOURCE_DIR,MIHOMO_CONFIG_DIR,MIHOMO_CONFIG,MIHOMO_SERVICE,MIHOMO_DOWNLOAD_BASE,MIHOMO_GITHUB_API,MIHOMO_UPSTREAM_SERVER,MIHOMO_UPSTREAM_PORT,MIHOMO_CONTROLLER_ADDRESS,MIHOMO_SECRET \
      bash "$0" "$subcommand" "$@"
    return $?
  fi
  case "$subcommand" in
    setup) setup_mihomo "$@" ;;
    download) download_mihomo "$@" ;;
    install-local) install_local_binary "$@" ;;
    start) start_service "$@" ;;
    stop) systemctl stop mihomo.service ;;
    restart) systemctl restart mihomo.service ;;
    uninstall) uninstall_mihomo "$@" ;;
    *) error "未知特权子命令：$subcommand"; return 1 ;;
  esac
}

require_linux_systemd() {
  [[ "$(uname -s)" == "Linux" ]] || {
    error "Mihomo TUN 部署只支持 Linux。"
    return 1
  }
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    error "不支持在 WSL 中部署 Mihomo TUN，请使用真实 Linux 主机或虚拟机。"
    return 1
  fi
  command -v systemctl >/dev/null 2>&1 || {
    error "未检测到 systemctl。此工具需要 systemd。"
    return 1
  }
  systemctl --version >/dev/null 2>&1 || {
    error "当前 systemctl 不可用，请在真实 systemd 环境中运行。"
    return 1
  }
}

detect_arch() {
  case "$(uname -m)" in
    x86_64) printf '%s\n' amd64 ;;
    aarch64) printf '%s\n' arm64 ;;
    *)
      error "仅支持 x86_64/amd64 和 aarch64/arm64，当前架构为 $(uname -m)。"
      return 1
      ;;
  esac
}

asset_name() {
  local arch
  arch="$(detect_arch)"
  case "$arch" in
    amd64) printf 'mihomo-linux-amd64-v2-%s.gz\n' "$MIHOMO_VERSION" ;;
    arm64) printf 'mihomo-linux-arm64-%s.gz\n' "$MIHOMO_VERSION" ;;
  esac
}

validate_version() {
  [[ "$MIHOMO_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    error "MIHOMO_VERSION 格式非法：$MIHOMO_VERSION（示例：v1.19.30）。"
    return 1
  }
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535))
}

validate_endpoint() {
  [[ "$1" =~ ^[A-Za-z0-9._:-]+$ ]] && [[ -n "$1" ]]
}

detect_lan_ip() {
  local address
  if command -v ip >/dev/null 2>&1; then
    address="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
    [[ -n "$address" ]] && { printf '%s\n' "$address"; return 0; }
  fi
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1; exit}'
  fi
}

extract_existing_secret() {
  [[ -f "$MIHOMO_CONFIG" ]] || return 0
  awk '
    /^[[:space:]]*secret:[[:space:]]*/ {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/^["'"'']|["'"'']$/, "")
      print
      exit
    }
  ' "$MIHOMO_CONFIG"
}

get_secret() {
  local existing
  if [[ -n "$MIHOMO_SECRET" ]]; then
    printf '%s\n' "$MIHOMO_SECRET"
    return 0
  fi
  existing="$(extract_existing_secret || true)"
  if [[ -n "$existing" ]]; then
    printf '%s\n' "$existing"
    return 0
  fi
  command -v openssl >/dev/null 2>&1 || {
    error "首次生成 secret 需要 openssl。"
    return 1
  }
  openssl rand -hex 32
}

print_download_guidance() {
  local asset
  asset="$(asset_name)"
  printf '\n请下载对应文件并放置到：\n'
  printf '  %s\n' "$MIHOMO_BINARY"
  printf '官方下载地址：\n  %s/%s/%s\n\n' "$MIHOMO_DOWNLOAD_BASE" "$MIHOMO_VERSION" "$asset"
  printf '也可以重新执行：bash mihomo.sh download\n'
}

find_local_binary_candidate() {
  local asset candidate
  asset="$(asset_name)"
  asset="${asset%.gz}"
  for candidate in "$MIHOMO_BINARY_SOURCE_DIR/mihomo" "$MIHOMO_BINARY_SOURCE_DIR/$asset"; do
    if [[ -f "$candidate" && "$candidate" != "$MIHOMO_BINARY" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

install_local_binary() {
  local source_path="${1:-}" temp_path
  if [[ -z "$source_path" ]]; then
    read -r -p "请输入已下载的 Mihomo 二进制路径: " source_path || return 1
  fi
  [[ -f "$source_path" ]] || {
    error "文件不存在：$source_path"
    return 1
  }
  [[ ! "$source_path" =~ \.gz$ ]] || {
    error "请先解压 .gz 文件，再安装解压后的二进制。"
    return 1
  }
  if [[ -e "$MIHOMO_BINARY" ]] && ! confirm "$MIHOMO_BINARY 已存在，是否覆盖"; then
    return 1
  fi
  mkdir -p "$(dirname "$MIHOMO_BINARY")"
  temp_path="$(mktemp "$(dirname "$MIHOMO_BINARY")/.mihomo.XXXXXX")"
  cp -- "$source_path" "$temp_path"
  chmod 0755 "$temp_path"
  if [[ -e "$MIHOMO_BINARY" ]]; then
    cp -a -- "$MIHOMO_BINARY" "$MIHOMO_BINARY.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mv -- "$temp_path" "$MIHOMO_BINARY"
  touch /var/lib/sh-tools-mihomo-binary
  success "Mihomo 二进制已安装：$MIHOMO_BINARY"
}

download_mihomo() {
  local asset api_json download_url digest archive temp_path
  validate_version
  command -v curl >/dev/null 2>&1 || { error "下载需要 curl。"; return 1; }
  command -v jq >/dev/null 2>&1 || { error "下载校验需要 jq。请先安装 jq，或手动安装二进制。"; return 1; }
  command -v gzip >/dev/null 2>&1 || { error "解压需要 gzip。"; return 1; }
  command -v sha256sum >/dev/null 2>&1 || { error "校验需要 sha256sum。"; return 1; }

  asset="$(asset_name)"
  api_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$MIHOMO_GITHUB_API/$MIHOMO_VERSION")" || {
    error "无法读取 Mihomo release 信息。"
    return 1
  }
  download_url="$(jq -r --arg asset "$asset" '.assets[] | select(.name == $asset) | .browser_download_url' <<<"$api_json")"
  digest="$(jq -r --arg asset "$asset" '.assets[] | select(.name == $asset) | (.digest // "")' <<<"$api_json")"
  [[ -n "$download_url" && "$download_url" != "null" ]] || {
    error "release 中不存在目标文件：$asset"
    return 1
  }
  [[ "$digest" == sha256:* ]] || {
    error "GitHub 未返回 $asset 的 sha256 digest，拒绝安装未校验文件。"
    return 1
  }
  digest="${digest#sha256:}"

  if [[ -e "$MIHOMO_BINARY" ]] && ! confirm "$MIHOMO_BINARY 已存在，是否下载并覆盖"; then
    return 1
  fi
  mkdir -p "$(dirname "$MIHOMO_BINARY")"
  archive="$(mktemp)"
  temp_path="$(mktemp "$(dirname "$MIHOMO_BINARY")/.mihomo.XXXXXX")"
  trap 'rm -f -- "${archive:-}" "${temp_path:-}"' RETURN
  info "下载 $asset"
  curl -fL --retry 3 "$download_url" -o "$archive"
  [[ "$(sha256sum "$archive" | awk '{print $1}')" == "$digest" ]] || {
    error "SHA256 校验失败，未安装文件。"
    return 1
  }
  gzip -dc "$archive" > "$temp_path"
  chmod 0755 "$temp_path"
  if [[ -e "$MIHOMO_BINARY" ]]; then
    cp -a -- "$MIHOMO_BINARY" "$MIHOMO_BINARY.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$(dirname "$MIHOMO_BINARY")"
  mv -- "$temp_path" "$MIHOMO_BINARY"
  touch /var/lib/sh-tools-mihomo-binary
  success "Mihomo $MIHOMO_VERSION 已安装：$MIHOMO_BINARY"
}

ensure_binary() {
  local local_candidate
  if [[ -x "$MIHOMO_BINARY" ]]; then
    return 0
  fi
  local_candidate="$(find_local_binary_candidate || true)"
  if [[ -n "$local_candidate" ]]; then
    info "检测到 /opt 下的 Mihomo 二进制：$local_candidate"
    install_local_binary "$local_candidate" || return 1
    return 0
  fi
  warn "未找到可执行文件：$MIHOMO_BINARY"
  if confirm "是否现在从官方 release 下载并校验"; then
    download_mihomo || return 1
  else
    print_download_guidance
    if confirm "是否输入已下载的本地二进制路径"; then
      install_local_binary || return 1
    else
      return 1
    fi
  fi
  [[ -x "$MIHOMO_BINARY" ]]
}

write_config() {
  local upstream_server="$1" upstream_port="$2" controller="$3" secret="$4" output="$5"
  mkdir -p "$MIHOMO_CONFIG_DIR"
  chmod 0700 "$MIHOMO_CONFIG_DIR"
  chmod 0600 "$output"
  cat > "$output" <<EOF
mixed-port: 7890
allow-lan: false
mode: global

external-controller: ${controller}:9090
secret: "${secret}"
external-controller-cors:
  allow-origins:
    - '*'
  allow-private-network: true

proxies:
  - name: PC-Clash
    type: socks5
    server: ${upstream_server}
    port: ${upstream_port}
    udp: true

proxy-groups:
  - name: GLOBAL
    type: select
    proxies:
      - PC-Clash

dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29

tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
    - tcp://any:53
  route-exclude-address:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - 127.0.0.0/8
    - 169.254.0.0/16
    - 224.0.0.0/4
EOF
}

write_service() {
  local output="$1"
  cat > "$output" <<EOF
# Managed by sh-tools mihomo
[Unit]
Description=Mihomo TUN Proxy
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$MIHOMO_CONFIG_DIR
ExecStartPre=/usr/bin/test -c /dev/net/tun
ExecStart=$MIHOMO_BINARY -d $MIHOMO_CONFIG_DIR
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
User=root

[Install]
WantedBy=multi-user.target
EOF
  chmod 0644 "$output"
}

validate_runtime_requirements() {
  local config_file="${1:-$MIHOMO_CONFIG}"
  [[ -x "$MIHOMO_BINARY" ]] || { error "Mihomo 二进制不可执行：$MIHOMO_BINARY"; return 1; }
  [[ -c /dev/net/tun ]] || { error "缺少 /dev/net/tun。"; return 1; }
  command -v nft >/dev/null 2>&1 || { error "未检测到 nftables（nft）。"; return 1; }
  "$MIHOMO_BINARY" -t -f "$config_file"
}

show_config_mihomo() {
  local mixed_port controller secret upstream_server upstream_port
  [[ -r "$MIHOMO_CONFIG" ]] || {
    error "配置文件不存在或不可读：$MIHOMO_CONFIG"
    return 1
  }
  mixed_port="$(awk '/^[[:space:]]*mixed-port:[[:space:]]*/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$MIHOMO_CONFIG")"
  controller="$(awk '/^[[:space:]]*external-controller:[[:space:]]*/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$MIHOMO_CONFIG")"
  secret="$(extract_existing_secret)"
  upstream_server="$(awk '/^[[:space:]]*server:[[:space:]]*/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$MIHOMO_CONFIG")"
  upstream_port="$(awk '/^[[:space:]]*port:[[:space:]]*/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$MIHOMO_CONFIG")"

  printf 'Mihomo 配置信息\n'
  printf '  配置文件：%s\n' "$MIHOMO_CONFIG"
  printf '  Mixed Port：%s\n' "${mixed_port:-未知}"
  printf '  Dashboard：http://%s\n' "${controller:-未知}"
  printf '  Secret：%s\n' "${secret:-未配置}"
  printf '  上游 SOCKS5：%s:%s\n' "${upstream_server:-未知}" "${upstream_port:-未知}"
}

manual_processes() {
  command -v pgrep >/dev/null 2>&1 || return 0
  local pid exe
  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ "$pid" != "$$" ]] || continue
    exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
    case "$exe" in
      */mihomo|*/mihomo-linux-*)
        ps -o pid=,args= -p "$pid" 2>/dev/null || printf '%s %s\n' "$pid" "$exe"
        ;;
    esac
  done < <(pgrep -f mihomo || true)
}

backup_existing_file() {
  local source="$1" backup
  [[ -f "$source" ]] || return 0
  backup="$(mktemp "${source}.bak.XXXXXX")"
  cp -a -- "$source" "$backup"
  printf '%s\n' "$backup"
}

rollback_setup() {
  local config_backup="$1" service_backup="$2" service_was_active="$3"
  local config_marker_was_present="$4"

  warn "Mihomo 新配置启动失败，正在恢复旧配置。"
  systemctl stop mihomo.service 2>/dev/null || true
  if [[ -n "$config_backup" && -f "$config_backup" ]]; then
    cp -a -- "$config_backup" "$MIHOMO_CONFIG"
  else
    rm -f -- "$MIHOMO_CONFIG"
  fi
  if [[ -n "$service_backup" && -f "$service_backup" ]]; then
    cp -a -- "$service_backup" "$MIHOMO_SERVICE"
  else
    rm -f -- "$MIHOMO_SERVICE"
  fi
  if ((config_marker_was_present)); then
    touch "$MIHOMO_CONFIG_DIR/.sh-tools-managed"
  else
    rm -f -- "$MIHOMO_CONFIG_DIR/.sh-tools-managed"
  fi
  systemctl daemon-reload 2>/dev/null || true
  if ((service_was_active)); then
    if ! systemctl start mihomo.service; then
      warn "旧 Mihomo 服务也未能恢复，请检查：journalctl -u mihomo -n 100 --no-pager"
    fi
  fi
}

start_service() {
  require_linux_systemd
  systemctl start mihomo.service
  success "Mihomo 服务已启动。"
}

setup_mihomo() {
  local upstream_server upstream_port controller secret processes
  local candidate_config candidate_service config_backup service_backup
  local service_was_active=0 config_marker_was_present=0
  require_linux_systemd
  validate_version
  ensure_binary || return 1
  command -v ip >/dev/null 2>&1 || warn "未检测到 ip，无法自动检测局域网地址。"

  upstream_server="$MIHOMO_UPSTREAM_SERVER"
  upstream_port="$MIHOMO_UPSTREAM_PORT"
  controller="${MIHOMO_CONTROLLER_ADDRESS:-$(detect_lan_ip)}"
  [[ -n "$controller" ]] || { error "无法自动检测 Dashboard 监听地址，请设置 MIHOMO_CONTROLLER_ADDRESS。"; return 1; }
  if [[ -z "$MIHOMO_UPSTREAM_SERVER_INPUT" ]]; then
    read -r -p "上游 SOCKS5 地址 [$upstream_server]: " upstream_server_input || return 1
    upstream_server="${upstream_server_input:-$upstream_server}"
  fi
  if [[ -z "$MIHOMO_UPSTREAM_PORT_INPUT" ]]; then
    read -r -p "上游 SOCKS5 端口 [$upstream_port]: " upstream_port_input || return 1
    upstream_port="${upstream_port_input:-$upstream_port}"
  fi
  if [[ -z "$MIHOMO_CONTROLLER_ADDRESS_INPUT" ]]; then
    read -r -p "Dashboard 监听地址 [$controller]: " controller_input || return 1
    controller="${controller_input:-$controller}"
  fi
  validate_endpoint "$upstream_server" || { error "上游地址格式非法：$upstream_server"; return 1; }
  validate_port "$upstream_port" || { error "上游端口格式非法：$upstream_port"; return 1; }
  validate_endpoint "$controller" || { error "Dashboard 监听地址格式非法：$controller"; return 1; }
  secret="$(get_secret)"
  [[ "$secret" =~ ^[A-Za-z0-9._~+/=-]+$ ]] || { error "secret 含有不安全字符。"; return 1; }

  mkdir -p "$MIHOMO_CONFIG_DIR" "$(dirname "$MIHOMO_SERVICE")"
  candidate_config="$(mktemp "$MIHOMO_CONFIG_DIR/.config.yaml.XXXXXX")"
  candidate_service="$(mktemp "$(dirname "$MIHOMO_SERVICE")/.mihomo.service.XXXXXX")"
  if ! write_config "$upstream_server" "$upstream_port" "$controller" "$secret" "$candidate_config" ||
     ! write_service "$candidate_service"; then
    rm -f -- "$candidate_config" "$candidate_service"
    error "生成候选配置失败，现有配置未改动。"
    return 1
  fi
  if ! validate_runtime_requirements "$candidate_config"; then
    rm -f -- "$candidate_config" "$candidate_service"
    error "候选配置校验失败，现有配置未改动。"
    return 1
  fi
  processes="$(manual_processes)"
  if [[ -n "$processes" ]] && ! systemctl is-active --quiet mihomo.service; then
    warn "检测到 Mihomo 手工进程，脚本不会自动结束它："
    printf '%s\n' "$processes"
    if ! confirm "是否继续启动 systemd 服务"; then
      rm -f -- "$candidate_config" "$candidate_service"
      return 1
    fi
  fi
  systemctl is-active --quiet mihomo.service && service_was_active=1 || true
  [[ -f "$MIHOMO_CONFIG_DIR/.sh-tools-managed" ]] && config_marker_was_present=1
  config_backup="$(backup_existing_file "$MIHOMO_CONFIG")"
  service_backup="$(backup_existing_file "$MIHOMO_SERVICE")"
  if ! mv -- "$candidate_config" "$MIHOMO_CONFIG" ||
     ! mv -- "$candidate_service" "$MIHOMO_SERVICE"; then
    rm -f -- "$candidate_config" "$candidate_service"
    rollback_setup "$config_backup" "$service_backup" "$service_was_active" "$config_marker_was_present"
    error "替换配置文件失败，已尝试恢复旧配置。"
    return 1
  fi
  chmod 0600 "$MIHOMO_CONFIG"
  chmod 0644 "$MIHOMO_SERVICE"
  touch "$MIHOMO_CONFIG_DIR/.sh-tools-managed"
  if ! systemctl daemon-reload; then
    rollback_setup "$config_backup" "$service_backup" "$service_was_active" "$config_marker_was_present"
    error "systemd 重新加载失败，已尝试恢复旧配置。"
    return 1
  fi
  if ((service_was_active)); then
    if ! systemctl restart mihomo.service; then
      rollback_setup "$config_backup" "$service_backup" "$service_was_active" "$config_marker_was_present"
      error "Mihomo 重启失败，已尝试恢复旧配置。"
      return 1
    fi
  else
    if ! systemctl start mihomo.service; then
      rollback_setup "$config_backup" "$service_backup" "$service_was_active" "$config_marker_was_present"
      error "Mihomo 启动失败，已尝试恢复旧配置。"
      return 1
    fi
  fi
  if ! systemctl is-active --quiet mihomo.service; then
    rollback_setup "$config_backup" "$service_backup" "$service_was_active" "$config_marker_was_present"
    error "Mihomo 未进入 active 状态，已尝试恢复旧配置。"
    return 1
  fi
  printf '\n%sDashboard 地址：%shttp://%s:9090%s\n' "$BLUE" "$BLUE" "$controller" "$RESET"
  printf '%sSecret：%s%s%s\n' "$BLUE" "$GREEN" "$secret" "$RESET"
  printf 'systemd enabled 状态：%s\n' "$(systemctl is-enabled mihomo.service 2>/dev/null || true)"
  success "Mihomo 已配置并启动；脚本不会执行 systemctl enable。"
}

uninstall_mihomo() {
  require_linux_systemd
  if ! confirm "停止并移除 Mihomo systemd 服务"; then return 1; fi
  systemctl stop mihomo.service 2>/dev/null || true
  if [[ -f "$MIHOMO_SERVICE" ]] && grep -Fq '# Managed by sh-tools mihomo' "$MIHOMO_SERVICE"; then
    rm -f -- "$MIHOMO_SERVICE"
    systemctl daemon-reload
  fi
  if [[ -f "$MIHOMO_CONFIG_DIR/.sh-tools-managed" ]]; then
    local backup_dir="${MIHOMO_CONFIG_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    mv -- "$MIHOMO_CONFIG_DIR" "$backup_dir"
    info "配置目录已移至备份：$backup_dir"
  fi
  if [[ -f /var/lib/sh-tools-mihomo-binary ]]; then
    rm -f -- "$MIHOMO_BINARY" /var/lib/sh-tools-mihomo-binary
  fi
  success "Mihomo 服务已移除；未由本工具安装的二进制不会删除。"
}

status_mihomo() {
  systemctl status mihomo.service --no-pager
}

logs_mihomo() {
  journalctl -u mihomo.service -f
}

interactive_menu() {
  local choice
  while true; do
    cat <<'EOF'

Mihomo TUN 工具
1) 配置并启动
2) 下载 Mihomo 二进制
3) 安装本地二进制
4) 启动服务
5) 停止服务
6) 重启服务
7) 查看状态
8) 查看配置、secret 和端口
9) 查看日志
10) 卸载服务与本工具创建的资源
0) 返回
EOF
    read -r -p "请选择操作: " choice || return 0
    case "$choice" in
      0) return 0 ;;
      1) run_privileged_subcommand setup ;;
      2) run_privileged_subcommand download ;;
      3) run_privileged_subcommand install-local ;;
      4) run_privileged_subcommand start ;;
      5) run_privileged_subcommand stop ;;
      6) run_privileged_subcommand restart ;;
      7) status_mihomo || true ;;
      8) show_config_mihomo || true ;;
      9) logs_mihomo ;;
      10) run_privileged_subcommand uninstall ;;
      *) warn "无效选项。" ;;
    esac
  done
}

main() {
  local command="${1:-menu}"
  case "$command" in
    menu) interactive_menu ;;
    setup) run_privileged_subcommand setup ;;
    download) run_privileged_subcommand download ;;
    install-local) run_privileged_subcommand install-local "${2:-}" ;;
    start) run_privileged_subcommand start ;;
    stop) run_privileged_subcommand stop ;;
    restart) run_privileged_subcommand restart ;;
    status) status_mihomo ;;
    show-config|config|info) show_config_mihomo ;;
    logs) logs_mihomo ;;
    uninstall) run_privileged_subcommand uninstall ;;
    -h|--help|help) usage ;;
    *) error "未知命令：$command"; usage; return 1 ;;
  esac
}

main "$@"
