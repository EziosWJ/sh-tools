#!/usr/bin/env bash
#
# wg-client.sh — 中心化 WireGuard 虚拟局域网的工控机端管理工具
#
# 职责：本地密钥生成、wg0.conf 初始化向导、状态查询、分流检查、交互式启停。
# 边界：私钥永不出本机；不负责服务端的 Peer 注册（由操作员把公钥提交给服务端）。
#
# 用法：
#   交互菜单（默认）：sudo ./wg-client.sh
#   子命令：          sudo ./wg-client.sh init
#                     ./wg-client.sh pubkey | split-check | status
#                     sudo ./wg-client.sh start | restart | stop
#
# 设计决策与术语见同目录 DESIGN.md。

set -uo pipefail

# ---------------------------------------------------------------------------
# 拒绝远程单文件执行（curl | bash）：本脚本在本机生成私钥，禁止远程 pipe 跑。
# ---------------------------------------------------------------------------
script_path="${BASH_SOURCE[0]}"
if [[ "$script_path" == "bash" || "$script_path" == "-" ||
      "$script_path" == /dev/fd/* || ! -f "$script_path" ]]; then
  echo "本脚本需在本机生成私钥，不支持 curl | bash 远程执行。"
  echo "请先 clone 仓库后本地运行："
  echo "  git clone <repo> && cd sh-tools/wireguard && sudo bash wg-client.sh"
  exit 1
fi

# ---------------------------------------------------------------------------
# 可改的变量
# ---------------------------------------------------------------------------
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_CONF="${WG_CONF:-/etc/wireguard/wg0.conf}"
WG_KEY="${WG_KEY:-/etc/wireguard/${WG_INTERFACE}_private.key}"
WG_SUBNET="${WG_SUBNET:-10.77.0.0/24}"
KEEPALIVE="${KEEPALIVE:-25}"
SERVER_ENDPOINT="${SERVER_ENDPOINT:-}"                   # 服务端公网 Endpoint
SERVER_PUBKEY="${SERVER_PUBKEY:-}"                     # 服务端公钥
CLIENT_IP="${CLIENT_IP:-}"                             # 本机 VPN IP

# ---------------------------------------------------------------------------
# 颜色 helper
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
  CYN='\033[0;36m';  BLD='\033[1m';    NC='\033[0m'
else
  RED=''; GRN=''; YLW=''; CYN=''; BLD=''; NC=''
fi
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
warn()    { echo -e "${YLW}[WARN]${NC} $*" >&2; }
info()    { echo -e "${CYN}[INFO]${NC} $*"; }
ok()      { echo -e "${GRN}[OK]${NC} $*"; }
banner()  { echo -e "\n${BLD}==== $* ====${NC}\n"; }

# ---------------------------------------------------------------------------
# 前提检查：wireguard 与 root
# ---------------------------------------------------------------------------
check_wireguard() {
  local missing=()
  command -v wg       >/dev/null 2>&1 || missing+=("wg")
  command -v wg-quick >/dev/null 2>&1 || missing+=("wg-quick")
  if ((${#missing[@]} > 0)); then
    echo -e "${RED}未检测到 WireGuard 工具：${missing[*]}${NC}"
    echo "请先按操作指南安装："
    echo "  sudo apt update && sudo apt install -y wireguard"
    return 1
  fi
  return 0
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo -e "${YLW}本操作需要 root 权限，尝试 sudo 重执行……${NC}"
    exec sudo "$0" "$@"
  fi
}

# ---------------------------------------------------------------------------
# 地址工具
# ---------------------------------------------------------------------------
_net="${WG_SUBNET%/*}"
SUBNET_PREFIX="${_net%.*}"

validate_vpn_ip() {
  local ip="$1"
  [[ "$ip" == "${SUBNET_PREFIX}."* ]] || { echo "IP $ip 不在子网 ${WG_SUBNET} 内"; return 1; }
  local o="${ip##*.}"
  (( o >= 1 && o <= 254 )) || { echo "IP $ip 的主机位非法"; return 1; }
  return 0
}

validate_pubkey() {
  local k="$1"
  [[ ${#k} -eq 44 ]] || { echo "公钥长度应为 44，实际 ${#k}"; return 1; }
  [[ "$k" =~ ^[A-Za-z0-9+/]+=*$ ]] || { echo "公钥字符集不合法（应为一组 base64）"; return 1; }
  return 0
}

validate_endpoint() {
  local ep="$1"
  # host:port（host 可为 IP 或域名）
  [[ "$ep" =~ ^[A-Za-z0-9._-]+:[0-9]+$ ]] || { echo "Endpoint 应为 host:port（如 vpn.example.com:51820）"; return 1; }
  local port="${ep##*:}"
  (( port >= 1 && port <= 65535 )) || { echo "端口非法：$port"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# 本地密钥生成（私钥存 WG_KEY，公钥回显）
# ---------------------------------------------------------------------------
ensure_keypair() {
  if [[ -f "$WG_KEY" ]]; then
    return 0
  fi
  info "未检测到本机密钥，现场生成密钥对……"
  sudo mkdir -p -m 700 "$(dirname "$WG_KEY")" 2>/dev/null || true
  umask 077
  wg genkey | tee "$WG_KEY" | wg pubkey >"${WG_KEY%.key}.pub" 2>/dev/null || true
  if [[ ! -f "$WG_KEY" ]]; then
    # root 路径下 fallback：仍存 /etc/wireguard
    local dir; dir="$(dirname "$WG_KEY")"
    install -d -m 700 "$dir" 2>/dev/null || die "无法创建密钥目录 $dir"
    wg genkey | tee "$WG_KEY" | wg pubkey >"${WG_KEY%.key}.pub"
  fi
  chmod 600 "$WG_KEY" 2>/dev/null || true
  ok "密钥已生成：$WG_KEY"
}

client_pubkey() {
  if [[ -f "$WG_KEY" ]]; then
    wg pubkey <"$WG_KEY"
  elif [[ -f "${WG_KEY%.key}.pub" ]]; then
    cat "${WG_KEY%.key}.pub"
  else
    echo ""
  fi
}

# ---------------------------------------------------------------------------
# 本机公钥 / 配置摘要
# ---------------------------------------------------------------------------
show_myself() {
  banner "本机公钥与配置"
  local pk; pk="$(client_pubkey)"
  if [[ -n "$pk" ]]; then
    echo -e "${BLD}公钥：${NC}$pk"
    echo "（请把上述公钥提交给服务端，用于服务端 add-peer）"
  else
    info "尚未生成密钥，请使用「初始化配置」生成。"
  fi
  echo
  if [[ -f "$WG_CONF" ]]; then
    if [[ ! -r "$WG_CONF" ]]; then
      echo -e "${YLW}配置文件 $WG_CONF 不可读（权限 600），请用 sudo 重执行。${NC}"
    else
      echo -e "${BLD}当前 ${WG_CONF} 摘要：${NC}"
      grep -E '^[[:space:]]*(Address|AllowedIPs|Endpoint|PublicKey)[[:space:]]*=' "$WG_CONF" || true
      # 不打印 PrivateKey
    fi
  else
    info "尚未生成 wg0.conf，请使用「初始化配置」。"
  fi
}

# ---------------------------------------------------------------------------
# 初始化向导
# ---------------------------------------------------------------------------
cmd_init() {
  check_wireguard >/dev/null 2>&1 || return 1
  require_root

  banner "初始化 WireGuard 客户端配置"

  # 已有配置时确认覆盖
  if [[ -f "$WG_CONF" ]]; then
    warn "已存在 $WG_CONF，继续将覆盖。"
    read -rp "仍要继续？(y/N) " _y
    [[ "$_y" == "y" || "$_y" == "Y" ]] || { info "已取消"; return 0; }
    cp -a "$WG_CONF" "${WG_CONF}.bak" 2>/dev/null || true
  fi

  # Endpoint
  local endpoint="$SERVER_ENDPOINT"
  if [[ -z "$endpoint" ]]; then
    read -rp "服务端公网 Endpoint（如 vpn.example.com:51820）：" endpoint
  fi
  validate_endpoint "$endpoint" >/tmp/_wg_msg 2>&1 || die "$(cat /tmp/_wg_msg 2>/dev/null)"
  rm -f /tmp/_wg_msg

  # 服务端公钥
  local spk="$SERVER_PUBKEY"
  if [[ -z "$spk" ]]; then
    read -rp "服务端公钥（44 字符 base64）：" spk
  fi
  spk="${spk//[[:space:]]/}"
  validate_pubkey "$spk" >/tmp/_wg_msg 2>&1 || die "$(cat /tmp/_wg_msg 2>/dev/null)"
  rm -f /tmp/_wg_msg

  # 本机 VPN IP
  local ip="$CLIENT_IP"
  if [[ -z "$ip" ]]; then
    read -rp "本机的 VPN IP（${SUBNET_PREFIX}.x）：" ip
  fi
  validate_vpn_ip "$ip" >/tmp/_wg_msg 2>&1 || die "$(cat /tmp/_wg_msg 2>/dev/null)"
  rm -f /tmp/_wg_msg

  # 生成或复用本机密钥对
  ensure_keypair
  local cpk; cpk="$(client_pubkey)"
  if [[ -z "$cpk" ]]; then
    die "未能拿到本机公钥"
  fi

  # 写配置
  local dir; dir="$(dirname "$WG_CONF")"
  sudo install -d -m 700 "$dir" 2>/dev/null || true
  cat <<EOF | tee "$WG_CONF" >/dev/null
[Interface]
Address = ${ip}/24
PrivateKey = $(cat "$WG_KEY")

[Peer]
PublicKey = ${spk}
Endpoint = ${endpoint}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = ${KEEPALIVE}
EOF
  chmod 600 "$WG_CONF"

  ok "配置已写入：$WG_CONF"
  echo
  banner "请把下面这个公钥提交给服务端"
  echo -e "${BLD}${cpk}${NC}"
  echo
  info "在服务端执行：sudo ./wg-server.sh add-peer --role ipc"

  # 是否立即启动
  echo
  read -rp "是否立即启动连接？(Y/n) " _y
  if [[ "$_y" != "n" && "$_y" != "N" ]]; then
    svc_action start >/dev/null 2>&1 || true
    sleep 1
    echo
    banner "连通性验证"
    wg show "$WG_INTERFACE" 2>/dev/null | grep -A4 "peer: ${spk}" || true
    echo
    ping -c 3 -W 2 "${SUBNET_PREFIX}.1" 2>/dev/null || warn "尚未 ping 通服务端，可能稍后才建立握手"
  fi
}

# ---------------------------------------------------------------------------
# 功能：查看状态
# ---------------------------------------------------------------------------
show_status() {
  check_wireguard >/dev/null 2>&1 || return 1
  banner "客户端状态"
  ip -br addr show "$WG_INTERFACE" 2>/dev/null || true
  echo
  wg show "$WG_INTERFACE" 2>/dev/null || true
  echo
  if [[ -f "$WG_CONF" ]]; then
    info "配置文件：$WG_CONF"
  else
    info "配置文件不存在：$WG_CONF"
  fi
}

# ---------------------------------------------------------------------------
# 功能：分流检查（验证非全隧道）
# ---------------------------------------------------------------------------
split_check() {
  banner "分流检查（预期：仅 VPN 网段走 ${WG_INTERFACE}，其余走原网关）"
  local vpn_target="${SUBNET_PREFIX}.1"
  echo -e "访问 ${vpn_target}（VPN 网段）："
  ip route get "$vpn_target" 2>/dev/null
  echo
  echo "访问 1.1.1.1（公共互联网）："
  ip route get 1.1.1.1 2>/dev/null
  echo
  info "判断："
  info "  - VPN 网段应走 dev ${WG_INTERFACE}"
  info "  - 互联网应走原物理网卡（eth0/enp*/wlan 等），不能走 dev ${WG_INTERFACE}"
  echo
  if ip route get 1.1.1.1 2>/dev/null | grep -q "dev ${WG_INTERFACE}"; then
    warn "疑似全隧道：互联网流量进入了 ${WG_INTERFACE}，请检查 AllowedIPs 是否误设为 0.0.0.0/0"
  else
    ok "分流正常"
  fi
}

# ---------------------------------------------------------------------------
# 启停
# ---------------------------------------------------------------------------
svc_action() {
  check_wireguard >/dev/null 2>&1 || return 1
  case "$1" in
    start)   systemctl enable --now "wg-quick@${WG_INTERFACE}" && ok "已启动" ;;
    restart) systemctl restart "wg-quick@${WG_INTERFACE}" && ok "已重启" ;;
    stop)    systemctl stop "wg-quick@${WG_INTERFACE}" && ok "已停止" ;;
    status)  systemctl is-active --quiet "wg-quick@${WG_INTERFACE}" && echo "wg-quick@${WG_INTERFACE}：运行中" || echo "wg-quick@${WG_INTERFACE}：未运行" ;;
  esac
}

# ---------------------------------------------------------------------------
# 服务控制子菜单
# ---------------------------------------------------------------------------
service_menu() {
  while :; do
    banner "服务控制"
    echo "  1) 启动"
    echo "  2) 重启"
    echo "  3) 停止"
    echo "  4) 查看服务状态"
    echo "  0) 返回上级"
    read -rp "请选择：" c
    case "$c" in
      1) require_root; svc_action start ;;
      2) require_root; svc_action restart ;;
      3) require_root; svc_action stop ;;
      4) svc_action status ;;
      0) break ;;
      *) warn "无效选择" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# 主菜单
# ---------------------------------------------------------------------------
main_menu() {
  while :; do
    banner "WireGuard 工控机端管理 (${WG_INTERFACE} @ ${WG_CONF})"
    echo "  1) 查看状态        （接口 / 握手 / 流量）"
    echo "  2) 本机公钥 / 配置 （抄公钥给服务端；看当前配置摘要）"
    echo "  3) 分流检查        （验证非全隧道）"
    echo "  4) 服务控制        （启动/重启/停止/状态）"
    echo "  5) 初始化配置      （init 向导，首次使用）"
    echo "  0) 退出"
    read -rp "请选择：" c
    case "$c" in
      1) show_status ;;
      2) show_myself ;;
      3) split_check ;;
      4) service_menu ;;
      5) require_root; cmd_init ;;
      0) echo "再见。"; exit 0 ;;
      *) warn "无效选择" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# 入口：子命令 / 菜单双模式
# ---------------------------------------------------------------------------
case "${1:-}" in
  init)          shift; require_root; cmd_init "$@" ;;
  pubkey)        check_wireguard >/dev/null 2>&1
                  pk="$(client_pubkey)"
                  if [[ -n "$pk" ]]; then
                    echo "$pk"
                  else
                    echo -e "${YLW}本机尚未生成密钥，请先 sudo $0 init 初始化。${NC}" >&2
                    exit 1
                  fi ;;
  status)        show_status ;;
  split-check)   split_check ;;
  start|restart|stop|status-svc)
                 require_root; svc_action "${1}" ;;
  help|-h|--help)
    echo "用法："
    echo "  $0                交互菜单"
    echo "  $0 init           初始化客户端配置（交互式）"
    echo "  $0 pubkey         显示本机公钥（可提交给服务端）"
    echo "  $0 status         查看接口与握手状态"
    echo "  $0 split-check    分流检查（验证非全隧道）"
    echo "  $0 start | restart | stop | status-svc"
    ;;
  "")            main_menu ;;
  *)             die "未知子命令：$1（执行 $0 help 查看帮助）" ;;
esac
