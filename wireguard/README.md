# WireGuard 管理工具

中心化 WireGuard 虚拟局域网的 **配置与密钥管理工具**，配套《使用原生 WireGuard 搭建中心化虚拟局域网》文档使用。

| 脚本 | 跑在哪 | 干什么 |
|---|---|---|
| `wg-server.sh` | 公网 Ubuntu 服务器（hub） | 管理 Peer 注册、地址段分配、交互式启停、状态查询 |
| `wg-client.sh` | 每台工控机 / 管理电脑（spoke） | 本地生成密钥对、初始化 `wg0.conf`、分流检查、启停 |

设计决策与术语定义见同目录 [`DESIGN.md`](./DESIGN.md)。

---

## 前提

脚本 **不** 负责以下工作，请在开始前按操作指南手工完成：

- 安装 `wireguard`、`iptables`
- 开启 `net.ipv4.ip_forward`
- 放行 UFW / 云平台安全组的 UDP 51820
- 服务端生成首份包含 `[Interface]` 的 `wg0.conf`

脚本只负责「在已有 WireGuard 环境上，做配置与密钥操作」。

---

## 安装

本脚本必须本地执行（拒绝 `curl | bash`），因为它要操作本机 `/etc/wireguard/`：

```bash
git clone https://github.com/EziosWJ/sh-tools.git
cd sh-tools/wireguard
```

也可以远程下载到临时目录后本地执行：

```bash
curl -fsSL -o wg-server.sh https://raw.githubusercontent.com/EziosWJ/sh-tools/master/wireguard/wg-server.sh
curl -fsSL -o wg-client.sh https://raw.githubusercontent.com/EziosWJ/sh-tools/master/wireguard/wg-client.sh
chmod +x wg-server.sh wg-client.sh
```

---

## 服务端 `wg-server.sh`

### 交互菜单（默认）

```bash
sudo ./wg-server.sh
```

```
==== WireGuard 服务端管理 (wg0 @ /etc/wireguard/wg0.conf) ====

  1) 查看状态        （接口 / Peer / 健康提示）
  2) 添加 Peer       （角色 → IP → 公钥 → 热加载）
  3) 删除 Peer       （序号 / IP / 公钥，二次确认）
  4) 公钥清单        （服务端 + 各 Peer）
  5) 服务控制        （启动/重启/停止/状态）
  0) 退出
```

### 命令速记（子命令）

```bash
sudo ./wg-server.sh add-peer --role ipc                     # 自动分配工控机段 IP
sudo ./wg-server.sh add-peer --role admin --ip 10.77.0.5     # 手动指定 IP
sudo ./wg-server.sh add-peer --role ipc --pubkey <base64>    # 直接给公钥（免交互）
sudo ./wg-server.sh remove-peer 10.77.0.11                   # 按 IP 删
sudo ./wg-server.sh remove-peer 2                            # 按序号删
sudo ./wg-server.sh list                                     # 列出所有 Peer
sudo ./wg-server.sh pubkey                                   # 仅输出服务端公钥
sudo ./wg-server.sh status                                   # 接口、Peer、健康提示
sudo ./wg-server.sh start | restart | stop | status-svc      # 服务控制
```

添加 Peer 时脚本采用 `wg syncconf` **零停机热加载**，不会中断已有工控机的连接；若不可用则回退 `systemctl restart`。

### 健康提示

「查看状态」会自动检查：

- **IP 冲突**：两个 Peer 声明了同一个 IP
- **从未握手**：配置了但 `wg show` 没有握手记录
- **运行时 Peer 不在配置里**：用 `wg add` 临时添加但未写回文件

---

## 工控机端 `wg-client.sh`

### 交互菜单（默认）

```bash
sudo ./wg-client.sh
```

```
==== WireGuard 工控机端管理 (wg0 @ /etc/wireguard/wg0.conf) ====

  1) 查看状态        （接口 / 握手 / 流量）
  2) 本机公钥 / 配置 （抄公钥给服务端；看当前配置摘要）
  3) 分流检查        （验证非全隧道）
  4) 服务控制        （启动/重启/停止/状态）
  5) 初始化配置      （init 向导，首次使用）
  0) 退出
```

### 命令速记（子命令）

```bash
sudo ./wg-client.sh init                                     # 初始化向导（交互式）
./wg-client.sh pubkey                                        # 仅输出本机公钥（可提交给服务端）
./wg-client.sh status                                        # 接口与握手状态
./wg-client.sh split-check                                   # 分流检查（验证非全隧道）
sudo ./wg-client.sh start | restart | stop | status-svc      # 服务控制
```

### init 向导要点

- **私钥永不出本机**：`wg genkey` 现场生成，私钥存在 `/etc/wireguard/wg0_private.key`（权限 600）
- 引导填入服务端 Endpoint、服务端公钥、本机 VPN IP
- 完成后**高亮提示本机公钥**，请把它提交给服务端
- 可选立即启动，并自动 `ping` 服务端验证连通

### 分流检查

`split-check` 会分别查 `ip route get 10.77.0.1`（VPN 网段）和 `ip route get 1.1.1.1`（互联网）：

- VPN 网段应走 `dev wg0`
- 互联网应走原物理网卡（`eth0`/`enp*` 等），**不能走 `dev wg0`**

若互联网流量进了 `wg0`，说明 `AllowedIPs` 误设成了 `0.0.0.0/0`，形成全隧道。

---

## 典型工作流：从零加一台工控机

```bash
# 【工控机端】初始化配置，拿到本机公钥
sudo ./wg-client.sh init
# → 填入服务端 Endpoint / 服务端公钥 / 本机 VPN IP（如 10.77.0.11）
# → 屏幕显示本机公钥，抄下来

# 【服务端】注册这台工控机
sudo ./wg-server.sh add-peer --role ipc
# → 自动分配工控机段第一个空闲 IP
# → 粘贴工控机公钥
# → 原子写回 wg0.conf + syncconf 热加载
# → 屏幕回显「客户端这样配」的模板
```

验证：

```bash
# 服务端
sudo ./wg-server.sh status        # 看到新 Peer 出现握手

# 工控机端
./wg-client.sh split-check       # 确认分流正常
ping 10.77.0.1                   # 能 ping 通服务端
```

---

## 网段自定义

两个脚本顶部都有可改的变量，换网段/端口只改一处：

```bash
WG_SUBNET="10.77.0.0/24"
WG_SERVER_IP="10.77.0.1"
WG_PORT="51820"
WG_PUBLIC_ENDPOINT=""              # 客户端看到的 Endpoint（公网 IP 或域名）
ADMIN_RANGE="2-10"
IPC_RANGE="11-199"
RESERVED_RANGE="200-254"
KEEPALIVE="25"
```

也可通过环境变量覆盖，便于离线测试不碰真配置：

```bash
WG_CONF=/tmp/test.conf ./wg-server.sh list
```

---

## 安全提示

- **私钥不跨机器**：服务端私钥由安装时一次性生成，脚本写回时原样保留、从不打印；客户端私钥只在工控机本机生成
- **所有 `.conf` / 密钥文件权限 600**，脚本写回后强制 `chmod 600`
- **写回采用原子操作**：写前备份 `.bak`，写到临时文件后 `mv` 覆盖，避免中途出错毁配置
- **删除 Peer 需要二次确认**并展示完整信息；若设备 30 秒内握过手（在线），会额外警告一次
- 本脚本拒绝 `curl | bash` 远程跑，避免私钥/配置落到不明环境

---

## 常见问题

**添加完 Peer 依然只有服务端能访问，其他节点不通**

通常是服务器未开启 `net.ipv4.ip_forward` 或未放行 `wg0 → wg0` 转发，按操作指南 §9 处理。本脚本不替代这些步骤。

**工控机端从来不握手**

检查服务端是否已添加该工控机公钥、Endpoint 是否正确、UDP 51820 是否对工控机可达、`PersistentKeepalive = 25` 是否配置。

**wg syncconf 不可用**

服务端脚本会自动回退 `systemctl restart`。

---

## 不在本工具范围

- 自动安装 wireguard / 配置 ip_forward / 配置 UFW / 安全组
- 密钥轮换自动化、批量导入、抓包辅助
- 总入口 `sh-tools.sh` 暂未挂载本工具（稳定后再决定）

详见 [`DESIGN.md`](./DESIGN.md) 第 8 节「不在本次范围」。
