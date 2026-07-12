#!/usr/bin/env bash
#
# wg-server.sh — 中心化 WireGuard 虚拟局域网的服务端管理工具
#
# 职责：密钥与 Peer 管理、wg0.conf 结构化读写、地址段分配、交互式启停、状态查询。
# 边界：不安装 wireguard、不配置 ip_forward / UFW / 安全组（这些由人工按操作指南完成）。
#
# 用法：
#   交互菜单（默认）：sudo ./wg-server.sh
#   子命令：          sudo ./wg-server.sh add-peer --role ipc
#                     sudo ./wg-server.sh remove-peer 10.77.0.11
#                     sudo ./wg-server.sh list | pubkey | status | start | restart | stop
#
# 设计决策与术语见同目录 DESIGN.md。

set -uo pipefail

# ---------------------------------------------------------------------------
# 拒绝远程单文件执行（curl | bash）：本脚本必须操作本机 /etc/wireguard/。
# ---------------------------------------------------------------------------
script_path="${BASH_SOURCE[0]}"
if [[ "$script_path" == "bash" || "$script_path" == "-" ||
      "$script_path" == /dev/fd/* || ! -f "$script_path" ]]; then
  echo "本脚本需操作本机 WireGuard 配置，不支持 curl | bash 远程执行。"
  echo "请先 clone 仓库后本地运行："
  echo "  git clone <repo> && cd sh-tools/wireguard && sudo bash wg-server.sh"
  exit 1
fi

# ---------------------------------------------------------------------------
# 可改的变量（改一处即可换网段/端口）。可被环境变量覆盖。
# ---------------------------------------------------------------------------
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_CONF="${WG_CONF:-/etc/wireguard/wg0.conf}"
WG_BACKUP="${WG_CONF}.bak"
WG_SUBNET="${WG_SUBNET:-10.77.0.0/24}"
WG_SERVER_IP="${WG_SERVER_IP:-10.77.0.1}"
WG_PORT="${WG_PORT:-51820}"
WG_PUBLIC_ENDPOINT="${WG_PUBLIC_ENDPOINT:-}"   # 客户端配置里的 Endpoint，例如 vpn.example.com:51820
ADMIN_RANGE="${ADMIN_RANGE:-2-10}"
IPC_RANGE="${IPC_RANGE:-11-199}"
RESERVED_RANGE="${RESERVED_RANGE:-200-254}"

# 从网段派生前缀（10.77.0.0/24 -> 10.77.0）
_net="${WG_SUBNET%/*}"
SUBNET_PREFIX="${_net%.*}"

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
  command -v wg        >/dev/null 2>&1 || missing+=("wg")
  command -v wg-quick  >/dev/null 2>&1 || missing+=("wg-quick")
  if ((${#missing[@]} > 0)); then
    echo -e "${RED}未检测到 WireGuard 工具：${missing[*]}${NC}"
    echo "请先按操作指南安装："
    echo "  sudo apt update && sudo apt install -y wireguard iptables"
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
# 地址工具函数
# ---------------------------------------------------------------------------
ip_to_int() { local IFS='.'; read -r a b c d <<<"$1"; echo $(( (a<<24)+(b<<16)+(c<<8)+d )); }
int_to_ip() { local n=$1; printf "%d.%d.%d.%d" $((n>>24&255)) $((n>>16&255)) $((n>>8&255)) $((n&255)); }

role_by_last_octet() {
  local o="$1"
  case 1 in
    $(( o>=2 && o<=10 ))     ) echo "管理电脑" ;;
    $(( o>=11 && o<=199 ))   ) echo "工控机" ;;
    $(( o>=200 && o<=254 ))  ) echo "预留" ;;
    *)                         echo "其他" ;;
  esac
}

# 解析 "start-end" 返回 start end
parse_range() {
  local r="$1"
  RANGE_START="${r%%-*}"; RANGE_END="${r##*-}"
}

# last_octet -> 10.77.0.x
ip_from_octet() { echo "${SUBNET_PREFIX}.$1"; }

# 从 wg0.conf 解析：iface 块 + peers[] 数组
# iface=([0..n] lines incl. [Interface] header)   -- 原样保留
# peer_comment / peer_pubkey / peer_allowedips / peer_raw (index 对齐)
# peer_count 总 Peer 数
declare -a iface=()
declare -a peer_comment=() peer_pubkey=() peer_allowedips=() peer_raw=()
declare -i peer_count=0

parse_wg_conf() {
  local file="$1"
  iface=(); peer_comment=(); peer_pubkey=(); peer_allowedips=(); peer_raw=()
  peer_count=0

  if [[ ! -f "$file" ]]; then
    echo -e "${RED}配置文件不存在：$file${NC}" >&2
    return 1
  fi
  if [[ ! -r "$file" ]]; then
    echo -e "${RED}配置文件不可读：$file${NC}" >&2
    echo " wg0.conf 默认权限 600，通常需要 root。请用 sudo 重执行。" >&2
    return 1
  fi

  local phase="top" pending_comment="" current=-1 line
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "[Interface]")
        phase="iface"; iface+=("$line"); pending_comment=""; continue ;;
      "[Peer]")
        phase="peer"
        peer_comment[$peer_count]="$pending_comment"
        peer_raw[$peer_count]=""
        current=$peer_count
        peer_count+=1
        pending_comment=""
        continue ;;
    esac
    case "$phase" in
      iface) iface+=("$line") ;;
      peer)
        if [[ -n "${peer_raw[$current]}" ]]; then
          peer_raw[$current]="${peer_raw[$current]}"$'\n'"$line"
        else
          peer_raw[$current]="$line"
        fi
        ;;
      top)
        [[ "$line" =~ ^[[:space:]]*# ]] && pending_comment+="$line"$'\n'
        ;;
    esac
  done < "$file"

  local i pubkey ip
  for ((i=0; i<peer_count; i++)); do
    # 用 sub 削前缀，保留整段值；真实公钥以 '=' 结尾，不能再按 '=' 分割
    pubkey=$(printf '%s' "${peer_raw[$i]}" | awk '
      /^[[:space:]]*PublicKey[[:space:]]*=/ { sub(/^[[:space:]]*PublicKey[[:space:]]*=[[:space:]]*/, ""); print; exit }')
    ip=$(printf '%s' "${peer_raw[$i]}" | awk '
      /^[[:space:]]*AllowedIPs[[:space:]]*=/ { sub(/^[[:space:]]*AllowedIPs[[:space:]]*=[[:space:]]*/, ""); print; exit }')
    peer_pubkey[$i]="$pubkey"
    peer_allowedips[$i]="$ip"
  done
}

# 原子写回：备份 -> 写临时文件 -> mv -> chmod 600
write_wg_conf() {
  local file="$1"
  local dir; dir="$(dirname "$file")"
  if [[ ! -d "$dir" ]]; then
    die "配置目录不存在：$dir（请先 sudo mkdir -p -m 700 $dir）"
  fi
  cp -a "$file" "$WG_BACKUP" 2>/dev/null || true
  local tmp; tmp="$(mktemp "$dir/.wg0.conf.XXXXXX")" || die "创建临时文件失败"
  chmod 600 "$tmp"
  {
    printf '%s\n' "${iface[@]}"
    local i
    for ((i=0; i<peer_count; i++)); do
      echo
      echo "[Peer]"
      if [[ -n "${peer_comment[$i]}" ]]; then
        printf '%s' "${peer_comment[$i]}"
      fi
      echo "PublicKey = ${peer_pubkey[$i]}"
      echo "AllowedIPs = ${peer_allowedips[$i]}"
    done
  } > "$tmp"
  mv "$tmp" "$file" || { rm -f "$tmp"; die "写回失败，原配置未改动（备份：$WG_BACKUP）"; }
  chmod 600 "$file"
  ok "配置已写回：$file（备份：$WG_BACKUP）"
}

# 检查接口块是否具备 Address + PrivateKey
assert_interface_ready() {
  local has_addr=0 has_key=0 line
  for line in "${iface[@]}"; do
    [[ "$line" =~ ^[[:space:]]*Address[[:space:]]*= ]] && has_addr=1
    [[ "$line" =~ ^[[:space:]]*PrivateKey[[:space:]]*= ]] && has_key=1
  done
  if (( !has_addr || !has_key )); then
    echo -e "${RED}接口块 [Interface] 缺少 Address 或 PrivateKey。${NC}"
    echo "请先按操作指南完成服务端 wg0.conf 的接口配置（或使用 add-peer 前的初始化）。"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# 服务端公钥（从接口块 PrivateKey 派生，绝不打印私钥本身）
# ---------------------------------------------------------------------------
server_pubkey() {
  server_pubkey="" 2>/dev/null
  local priv
  priv=$(printf '%s\n' "${iface[@]}" | awk -F'=' '
    /^[[:space:]]*PrivateKey[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit }')
  if [[ -z "$priv" ]]; then
    echo -e "${YLW}接口块未找到 PrivateKey，无法派生服务端公钥。${NC}" >&2
    return 1
  fi
  printf '%s' "$priv" | wg pubkey 2>/dev/null
}

# ---------------------------------------------------------------------------
# IP 冲突 / 分配
# ---------------------------------------------------------------------------
# 填充关联数组 used[octet]=1（含服务端自身与各 Peer）
declare -A _used=()
collect_used_ips() {
  _used=()
  local ip="${WG_SERVER_IP%%/*}"
  _used[${ip##*.}]=1
  local i
  for ((i=0; i<peer_count; i++)); do
    ip="${peer_allowedips[$i]%%/*}"
    [[ -n "$ip" ]] && _used[${ip##*.}]=1
  done
}

# 返回某地址段第一个空闲 IP；找不到返回非 0
find_free_ip() {
  parse_range "$1"
  collect_used_ips
  local o
  for ((o=RANGE_START; o<=RANGE_END; o++)); do
    [[ -z "${_used[$o]+_}" ]] && { ip_from_octet "$o"; return 0; }
  done
  return 1
}

# ---------------------------------------------------------------------------
# 启动自检：地址段落在子网内、段间不重叠、不覆盖服务端 IP
# ---------------------------------------------------------------------------
validate_config_ranges() {
  local -A occ=() name_by range name
  for name in admin ipc reserved; do
    case "$name" in
      admin) range="$ADMIN_RANGE" ;;
      ipc)   range="$IPC_RANGE" ;;
      reserved) range="$RESERVED_RANGE" ;;
    esac
    parse_range "$range"
    if (( RANGE_START > RANGE_END )); then
      die "地址段定义颠倒：${name} = ${range}（start > end）"
    fi
    if (( RANGE_START < 1 || RANGE_END > 254 )); then
      die "地址段越界：${name} = ${range}（主机位需在 1..254 内）"
    fi
    # 端点必须落在子网内
    local s_ip; s_ip="$(ip_from_octet "$RANGE_START")"
    local e_ip; e_ip="$(ip_from_octet "$RANGE_END")"
    validate_manual_ip_quiet "$s_ip" "$range" || die "${name} 段起点 ${s_ip} 非法（需落在 ${WG_SUBNET}）"
    validate_manual_ip_quiet "$e_ip" "$range" || die "${name} 段终点 ${e_ip} 非法（需落在 ${WG_SUBNET}）"
    # 不与其它段重叠、不覆盖服务端 IP
    local o
    for ((o=RANGE_START; o<=RANGE_END; o++)); do
      local cur; cur="$(ip_from_octet "$o")"
      [[ "$cur" == "${WG_SERVER_IP%%/*}" ]] && die "地址段 ${name} 覆盖了服务端自身 IP ${cur}"
      if [[ -n "${occ[$o]+_}" ]]; then
        die "地址段重叠：${name} 与 ${name_by[$o]} 都包含 ${cur}"
      fi
      occ[$o]=1; name_by[$o]="$name"
    done
  done
}

# validate_manual_ip 的安静内联版（只校验子网+范围，不校验占用）
validate_manual_ip_quiet() {
  local ip="$1" range="$2"; parse_range "$range"
  [[ "$ip" == "${SUBNET_PREFIX}."* ]] || return 1
  local o="${ip##*.}"
  (( o >= RANGE_START && o <= RANGE_END )) || return 1
  return 0
}

# 校验手工指定 IP 的合法性：属于子网、在范围内、非服务端、未占用
validate_manual_ip() {
  local ip="$1" range="$2"
  validate_manual_ip_quiet "$ip" "$range" || {
    parse_range "$range"
    [[ "$ip" != "${SUBNET_PREFIX}."* ]] && { echo "IP $ip 不在子网 ${WG_SUBNET} 内"; return 1; }
    local o="${ip##*.}"
    (( o < RANGE_START || o > RANGE_END )) && { echo "IP $ip 不在段 ${range} 内"; return 1; }
  }
  [[ "$ip" == "${WG_SERVER_IP%%/*}" ]] && { echo "IP $ip 已被服务端自身占用"; return 1; }
  collect_used_ips
  local o="${ip##*.}"
  [[ -n "${_used[$o]+_}" ]] && { echo "IP $ip 已被某 Peer 占用"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# 公钥校验
# ---------------------------------------------------------------------------
validate_pubkey() {
  local k="$1"
  [[ ${#k} -eq 44 ]] || { echo "公钥长度应为 44，实际 ${#k}"; return 1; }
  [[ "$k" =~ ^[A-Za-z0-9+/]+=*$ ]] || { echo "公钥字符集不合法（应为一组 base64）"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# 当前 Peer 列表里的索引：按序号 1-based / IP / pubkey 查找
# ---------------------------------------------------------------------------
find_peer_index() {
  local target="$1" i
  # 数字序号 (1-based)
  if [[ "$target" =~ ^[0-9]+$ ]] && (( target>=1 && target<=peer_count )); then
    echo $((target-1)); return 0
  fi
  # IP
  for ((i=0; i<peer_count; i++)); do
    [[ "${peer_allowedips[$i]%%/*}" == "$target" ]] && { echo "$i"; return 0; }
  done
  # pubkey
  for ((i=0; i<peer_count; i++)); do
    [[ "${peer_pubkey[$i]}" == "$target" ]] && { echo "$i"; return 0; }
  done
  return 1
}

# ---------------------------------------------------------------------------
# 从 wg show 取某 Peer 的最近握手秒数（空表示从未握手）
# ---------------------------------------------------------------------------
last_handshake_secs() {
  local pubkey="$1"
  local line
  line=$(wg show "$WG_INTERFACE" 2>/dev/null | grep -A6 "peer: ${pubkey}" \
         | grep "latest handshake" | head -1)
  if [[ "$line" =~ latest\ handshake:\ ([0-9]+)\ second ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# ---------------------------------------------------------------------------
# 热加载：首选 wg syncconf；失败回退 systemctl restart
# ---------------------------------------------------------------------------
apply_conf() {
  check_wireguard >/dev/null 2>&1 || return 1
  if wg show "$WG_INTERFACE" >/dev/null 2>&1; then
    local stripped
    stripped="$(wg-quick strip "$WG_CONF" 2>/dev/null)" || true
    if [[ -n "$stripped" ]] && wg syncconf "$WG_INTERFACE" <(printf '%s' "$stripped") 2>/dev/null; then
      ok "已热加载（wg syncconf），现有连接未中断"
      return 0
    fi
    info "wg syncconf 未成功，回退为 systemctl restart ……"
  fi
  if systemctl restart "wg-quick@${WG_INTERFACE}" 2>/dev/null; then
    ok "已通过 systemctl restart 重新加载"
    return 0
  fi
  warn "热加载与 restart 均未成功，请手动检查：sudo systemctl status wg-quick@${WG_INTERFACE}"
  return 1
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
# 功能：查看状态
# ---------------------------------------------------------------------------
show_status() {
  check_wireguard || return 1
  banner "接口与 Peer 状态"
  ip -br addr show "$WG_INTERFACE" 2>/dev/null || true
  echo
  wg show "$WG_INTERFACE" 2>/dev/null || true

  echo
  banner "健康提示"
  local i has_issue=0

  # 0) 转发是否开启（节点间通信的前提）
  if [[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" != "1" ]]; then
    warn "net.ipv4.ip_forward 未开启（当前值非 1）—— 节点间转发将无法工作"
    has_issue=1
  fi

  # 1) IP 冲突
  collect_used_ips
  local -A seen_ip=() ip_first_idx=()
  for ((i=0; i<peer_count; i++)); do
    local ip="${peer_allowedips[$i]%%/*}"
    [[ -z "$ip" ]] && continue
    if [[ -n "${seen_ip[$ip]+_}" ]]; then
      warn "IP 冲突：$ip 同时被 Peer #${ip_first_idx[$ip]} 和 Peer #$i 声明"
      has_issue=1
    else
      seen_ip[$ip]=1; ip_first_idx[$ip]=$i
    fi
  done

  # 2) 从未握手
  for ((i=0; i<peer_count; i++)); do
    local secs; secs="$(last_handshake_secs "${peer_pubkey[$i]}")"
    if [[ -z "$secs" ]]; then
      warn "Peer #$i (${peer_allowedips[$i]%%/*}) 从未握手 —— 可能未生效/对端未配置"
      has_issue=1
    fi
  done

  # 3) 运行时 Peer 不在配置里
  local runtime_pubkeys
  runtime_pubkeys="$(wg show "$WG_INTERFACE" 2>/dev/null | awk '/^peer: /{print $2}')"
  if [[ -n "$runtime_pubkeys" ]]; then
    while IFS= read -r rpk; do
      local found=0
      for ((i=0; i<peer_count; i++)); do
        [[ "${peer_pubkey[$i]}" == "$rpk" ]] && { found=1; break; }
      done
      if (( !found )); then
        warn "运行时存在但配置里没有的 Peer：${rpk}（可能用 wg add 临时添加）"
        has_issue=1
      fi
    done <<<"$runtime_pubkeys"
  fi

  (( has_issue == 0 )) && ok "未发现明显异常"
}

# ---------------------------------------------------------------------------
# 功能：查看公钥清单
# ---------------------------------------------------------------------------
show_pubkeys() {
  banner "服务端公钥"
  local pk; pk="$(server_pubkey)"
  if [[ -n "$pk" ]]; then
    echo "$pk"
  else
    echo -e "${YLW}（未能派生，请检查接口块 PrivateKey）${NC}"
  fi
  echo
  banner "Peer 公钥清单"
  if (( peer_count == 0 )); then
    info "（暂无 Peer）"
    return
  fi
  printf "%-3s %-18s %-10s %s\n" "#" "IP" "角色" "PublicKey"
  printf "%-3s %-18s %-10s %s\n" "--" "--" "--" "---------"
  local i ip role
  for ((i=0; i<peer_count; i++)); do
    ip="${peer_allowedips[$i]%%/*}"
    role="$(role_by_last_octet "${ip##*.}")"
    printf "%-3s %-18s %-10s %s\n" "$((i+1))" "$ip" "$role" "${peer_pubkey[$i]}"
  done
}

# ---------------------------------------------------------------------------
# 功能：添加 Peer
# ---------------------------------------------------------------------------
cmd_add_peer() {
  check_wireguard || return 1
  parse_wg_conf "$WG_CONF" || return 1
  assert_interface_ready || return 1

  local role="" ip="" pubkey=""
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role)   role="$2";   shift 2 ;;
      --ip)     ip="$2";     shift 2 ;;
      --pubkey) pubkey="$2"; shift 2 ;;
      -h|--help)
        echo "用法：$0 add-peer [--role admin|ipc] [--ip 10.77.0.x] [--pubkey <base64>]"
        return 0 ;;
      *)        die "未知参数：$1" ;;
    esac
  done

  # 角色（决定地址段）
  if [[ -z "$role" ]]; then
    echo "选择新节点角色："
    echo "  1) 管理电脑（段 ${ADMIN_RANGE}）"
    echo "  2) 工控机（段 ${IPC_RANGE}）"
    read -rp "请选择 [1/2]：" _c
    case "$_c" in
      1) role="admin" ;; 2|*) role="ipc" ;;
    esac
  fi

  local range
  case "$role" in
    admin) range="$ADMIN_RANGE" ;;
    ipc)   range="$IPC_RANGE" ;;
    *)     die "未知角色：$role（应为 admin / ipc）" ;;
  esac

  # IP
  if [[ -z "$ip" ]]; then
    echo "可选："
    echo "  1) 自动分配（段内第一个空闲 IP）"
    echo "  2) 手动指定"
    read -rp "请选择 [1/2]：" _c
    if [[ "$_c" == "2" ]]; then
      read -rp "请输入 IP（${SUBNET_PREFIX}.x）：" ip
    else
      ip="$(find_free_ip "$range")" || die "段 ${range} 已无空闲 IP"
      info "自动分配：$ip"
    fi
  fi

  if ! validate_manual_ip "$ip" "$range" >/tmp/_wg_msg 2>&1; then
    die "$(cat /tmp/_wg_msg 2>/dev/null)"
  fi
  rm -f /tmp/_wg_msg

  # 公钥
  if [[ -z "$pubkey" ]]; then
    echo "请粘贴对端的 WireGuard 公钥（44 字符 base64），回车确认："
    read -rp "PublicKey = " pubkey
  fi
  pubkey="${pubkey//[[:space:]]/}"
  validate_pubkey "$pubkey" >/tmp/_wg_msg 2>&1 || die "$(cat /tmp/_wg_msg 2>/dev/null)"
  rm -f /tmp/_wg_msg

  # 检查公钥重复
  local i
  for ((i=0; i<peer_count; i++)); do
    [[ "${peer_pubkey[$i]}" == "$pubkey" ]] && die "该公钥已存在于 Peer #$((i+1))"
  done

  # 写入
  local idx=$peer_count
  peer_comment[$idx]="# $(role_by_last_octet "${ip##*.}") (${ip})"$'\n'
  peer_pubkey[$idx]="$pubkey"
  peer_allowedips[$idx]="${ip}/32"
  peer_count+=1
  write_wg_conf "$WG_CONF"

  # 热加载
  apply_conf

  # 回显客户端配置
  local spk; spk="$(server_pubkey)" || spk="(未能派生)"
  local endpoint="${WG_PUBLIC_ENDPOINT:-"<请填入服务端公网IP:端口>"}"
  banner "请在客户端使用以下配置"
  cat <<EOF
[Interface]
PrivateKey = <客户端私钥（已在对端本地生成）>
Address = ${ip}/24

[Peer]
PublicKey = ${spk}
Endpoint = ${endpoint}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = 25
EOF
  echo
  info "请在客户端以以上为模板，填入对端本地生成的私钥，然后启动。"
}

# ---------------------------------------------------------------------------
# 功能：删除 Peer
# ---------------------------------------------------------------------------
cmd_remove_peer() {
  check_wireguard >/dev/null 2>&1 || return 1
  parse_wg_conf "$WG_CONF" || return 1

  local target="$1"
  if [[ -z "$target" ]]; then
    cmd_list || true
    echo
    read -rp "输入要删除的 序号 / IP / 公钥（0 取消）：" target
  fi
  [[ "$target" == "0" ]] && { info "已取消"; return 0; }

  local idx
  idx="$(find_peer_index "$target")" || die "未找到匹配的 Peer：$target"

  local ip="${peer_allowedips[$idx]%%/*}" pk="${peer_pubkey[$idx]}"
  local secs; secs="$(last_handshake_secs "$pk")"
  local role; role="$(role_by_last_octet "${ip##*.}")"

  banner "即将删除 Peer"
  echo "  IP      : $ip"
  echo "  角色    : $role"
  echo "  公钥    : $pk"
  if [[ -n "$secs" ]]; then
    echo -e "  上次握手：${secs} 秒前"
  else
    echo "  上次握手：从未"
  fi

  echo
  read -rp "确认删除？(y/N) " _y
  [[ "$_y" == "y" || "$_y" == "Y" ]] || { info "已取消"; return 0; }

  # 在线警告（双保险）
  if [[ -n "$secs" ]] && (( secs < 30 )); then
    echo -e "${RED}⚠️ 该设备当前在线（${secs} 秒前还握手），删除会立刻中断它的连接。${NC}"
    read -rp "仍要删除？(y/N) " _y2
    [[ "$_y2" == "y" || "$_y2" == "Y" ]] || { info "已取消"; return 0; }
  fi

  # 从数组移除：重建不含 idx 的新数组
  local -a new_comment=() new_pubkey=() new_allowedips=() new_raw=()
  local j k=0
  for ((j=0; j<peer_count; j++)); do
    (( j == idx )) && continue
    new_comment[$k]="${peer_comment[$j]}"
    new_pubkey[$k]="${peer_pubkey[$j]}"
    new_allowedips[$k]="${peer_allowedips[$j]}"
    new_raw[$k]="${peer_raw[$j]}"
    k+=1
  done
  peer_comment=("${new_comment[@]+"${new_comment[@]}"}")
  peer_pubkey=("${new_pubkey[@]+"${new_pubkey[@]}"}")
  peer_allowedips=("${new_allowedips[@]+"${new_allowedips[@]}"}")
  peer_raw=("${new_raw[@]+"${new_raw[@]}"}")
  peer_count=$k

  write_wg_conf "$WG_CONF"
  apply_conf
  ok "已删除 Peer：$ip"
  echo
  info "善后提醒：请在对端手动清除其 wg0.conf 或停止 wg-quick，否则它会持续向本服务端的无效握手。"
}

# ---------------------------------------------------------------------------
# 功能：列出 Peer
# ---------------------------------------------------------------------------
cmd_list() {
  parse_wg_conf "$WG_CONF" || return 1
  banner "当前 Peer 列表"
  if (( peer_count == 0 )); then
    info "（暂无 Peer）"
    return 0
  fi
  printf "%-3s %-18s %-10s %-16s %s\n" "#" "IP" "角色" "上次握手" "PublicKey"
  printf "%-3s %-18s %-10s %-16s %s\n" "--" "--" "--" "--" "---------"
  local i ip role secs
  for ((i=0; i<peer_count; i++)); do
    ip="${peer_allowedips[$i]%%/*}"
    role="$(role_by_last_octet "${ip##*.}")"
    secs="$(last_handshake_secs "${peer_pubkey[$i]}")"
    [[ -n "$secs" ]] && secs="${secs}s ago" || secs="never"
    printf "%-3s %-18s %-10s %-16s %s\n" "$((i+1))" "$ip" "$role" "$secs" "${peer_pubkey[$i]}"
  done
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
  require_root
  validate_config_ranges
  while :; do
    banner "WireGuard 服务端管理 (${WG_INTERFACE} @ ${WG_CONF})"
    echo "  1) 查看状态        （接口 / Peer / 健康提示）"
    echo "  2) 添加 Peer       （角色 → IP → 公钥 → 热加载）"
    echo "  3) 删除 Peer       （序号 / IP / 公钥，二次确认）"
    echo "  4) 公钥清单        （服务端 + 各 Peer）"
    echo "  5) 服务控制        （启动/重启/停止/状态）"
    echo "  0) 退出"
    read -rp "请选择：" c
    case "$c" in
      1) show_status ;;
      2) cmd_add_peer ;;
      3) cmd_remove_peer ;;
      4) show_pubkeys ;;
      5) service_menu ;;
      0) echo "再见。"; exit 0 ;;
      *) warn "无效选择" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# 入口：子命令 / 菜单双模式
# ---------------------------------------------------------------------------
case "${1:-}" in
  add-peer)       shift; require_root; validate_config_ranges; cmd_add_peer "$@" ;;
  remove-peer)    shift; require_root; cmd_remove_peer "$@" ;;
  list)           validate_config_ranges; cmd_list ;;
  pubkey)         check_wireguard >/dev/null 2>&1; validate_config_ranges; parse_wg_conf "$WG_CONF" 2>/dev/null; server_pubkey || true ;;
  status)         show_status ;;
  start|restart|stop|status-svc)
                  require_root; svc_action "${1}" ;;
  help|-h|--help)
    echo "用法："
    echo "  $0                交互菜单"
    echo "  $0 add-peer [--role admin|ipc] [--ip 10.77.0.x] [--pubkey <base64>]"
    echo "  $0 remove-peer [序号|IP|公钥]"
    echo "  $0 list | pubkey | status"
    echo "  $0 start | restart | stop | status-svc"
    ;;
  "")             main_menu ;;
  *)              die "未知子命令：$1（执行 $0 help 查看帮助）" ;;
esac
