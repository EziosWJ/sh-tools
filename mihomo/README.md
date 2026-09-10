# mihomo

根据 [Mihomo TUN 部署文档](../mihomo-tun-docker-dashboard.md) 配置 Linux 主机：安装或引导准备 Mihomo、生成 `/etc/mihomo/config.yaml`、注册并启动 systemd 服务。

## 使用

```bash
bash mihomo.sh setup
bash mihomo.sh status
bash mihomo.sh show-config
bash mihomo.sh logs
```

也可以从仓库总入口执行：

```bash
bash sh-tools.sh mihomo setup
```

脚本只支持 Linux + systemd，并且只识别 `x86_64`/`amd64` 和 `aarch64`/`arm64`。二进制目标路径为 `/usr/local/bin/mihomo`，配置目录为 `/etc/mihomo`。

二进制不存在时，脚本会询问是否从官方 GitHub release 下载并校验；也可以选择手动下载后执行：

```bash
sudo bash mihomo.sh install-local /path/to/mihomo
```

脚本会启动服务，但不会执行 `systemctl enable mihomo`，因此不会设置开机自启动。它也不会修改 Docker daemon、主机防火墙或自动结束已有的 Mihomo 手工进程。

可通过环境变量覆盖版本、上游 SOCKS5 地址/端口、Dashboard 监听地址和 secret，详见：

```bash
bash mihomo.sh --help
```
