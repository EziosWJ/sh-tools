# proxyctl - 代理管理工具

一键管理 Shell、Git、NPM、APT、Docker 和 pip 的代理配置。

## 功能

- ✅ 设置/清除环境变量代理（http_proxy、https_proxy、all_proxy）
- ✅ 配置 Git 全局代理
- ✅ 配置 NPM 代理
- ✅ 配置 APT 代理（Debian/Ubuntu）
- ✅ 配置 Docker 代理（systemd）
- ✅ 配置 pip 代理
- ✅ 查看当前代理状态

## 快速安装

```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/EziosWJ/sh-tools/master/proxyctl/proxyctl.sh | sudo tee /usr/local/bin/proxyctl >/dev/null
sudo chmod +x /usr/local/bin/proxyctl
```

## 使用方法

### 启用代理

```bash
# 使用默认代理 (127.0.0.1:7890)
proxyctl on

# 使用自定义代理地址
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 SOCKS_PORT=7897 proxyctl on
```

### 临时 Shell 会话使用

使用 `source` 命令在当前 shell 中执行，环境变量会直接生效到当前会话：

```bash
# 方式一：安装后使用
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 SOCKS_PORT=7897 source /usr/local/bin/proxyctl on

# 方式二：直接使用脚本（无需安装）
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 SOCKS_PORT=7897 source proxyctl.sh on

# 验证环境变量已生效
echo $http_proxy
echo $https_proxy

# 关闭代理
source proxyctl.sh off
```

> **注意：** 使用 `source` 而非直接执行 `bash proxyctl.sh`，这样环境变量才会注入到当前 shell 会话中。

### 关闭代理

```bash
proxyctl off
```

### 启用 APT 代理

```bash
# 启用 APT 代理
proxyctl apt-on

# 关闭 APT 代理
proxyctl apt-off
```

### 启用 Docker 代理

Docker 代理通过 systemd 配置，需要 sudo 权限。

```bash
# 启用 Docker 代理（使用默认代理）
proxyctl docker-on

# 使用自定义代理地址
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 proxyctl docker-on

# 关闭 Docker 代理
proxyctl docker-off

# 查看 Docker 代理状态
proxyctl docker-status
```

> **注意：** Docker 代理配置会重启 Docker 服务，请确保没有正在运行的关键容器。

### 启用 pip 代理

pip 需要显式配置代理，不能依赖系统环境变量。

```bash
# 启用 pip 代理（使用默认代理）
proxyctl pip-on

# 使用自定义代理地址
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 proxyctl pip-on

# 关闭 pip 代理
proxyctl pip-off

# 查看 pip 代理状态
proxyctl pip-status
```

> **注意：** pip 代理配置会修改 `~/.config/pip/pip.conf` 文件。

### 查看代理状态

```bash
proxyctl status
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PROXY_HOST` | 代理主机地址 | `127.0.0.1` |
| `HTTP_PORT` | HTTP 代理端口 | `7890` |
| `SOCKS_PORT` | SOCKS5 代理端口 | `7890` |

## 命令列表

| 命令 | 说明 |
|------|------|
| `proxyctl on` | 启用代理（Shell + Git + NPM + pip） |
| `proxyctl off` | 关闭代理（Shell + Git + NPM + pip） |
| `proxyctl apt-on` | 启用 APT 代理 |
| `proxyctl apt-off` | 关闭 APT 代理 |
| `proxyctl docker-on` | 启用 Docker 代理 |
| `proxyctl docker-off` | 关闭 Docker 代理 |
| `proxyctl docker-status` | 查看 Docker 代理状态 |
| `proxyctl pip-on` | 启用 pip 代理 |
| `proxyctl pip-off` | 关闭 pip 代理 |
| `proxyctl pip-status` | 查看 pip 代理状态 |
| `proxyctl status` | 查看所有代理状态 |

## 示例

```bash
# 启用代理（使用 192.168.1.10:7897）
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 proxyctl on

# 启用 Docker 代理
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 proxyctl docker-on

# 启用 pip 代理
PROXY_HOST=192.168.1.10 HTTP_PORT=7897 proxyctl pip-on

# 查看所有代理状态
proxyctl status

# 关闭所有代理
proxyctl off
proxyctl docker-off
proxyctl pip-off
```

## 配置到 ~/.bashrc

将代理配置添加到 `~/.bashrc`，使其在每次打开终端时自动生效。

### 方式一：使用函数（推荐）

在 `~/.bashrc` 末尾添加以下内容：

```bash
# 代理管理函数
proxy_on() {
  PROXY_HOST=192.168.1.10 HTTP_PORT=7897 SOCKS_PORT=7897 source /usr/local/bin/proxyctl on
}

proxy_off() {
  source /usr/local/bin/proxyctl off
}

proxy_status() {
  source /usr/local/bin/proxyctl status
}
```

然后重新加载配置：

```bash
source ~/.bashrc

# 现在可以使用简化的命令
proxy_on      # 启用代理
proxy_off     # 关闭代理
proxy_status  # 查看状态
```

### 方式二：直接设置环境变量

在 `~/.bashrc` 末尾添加：

```bash
# 代理配置
export http_proxy="http://192.168.1.10:7897"
export https_proxy="http://192.168.1.10:7897"
export all_proxy="socks5://192.168.1.10:7897"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy"
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="$no_proxy"

# Git 代理
git config --global http.proxy "http://192.168.1.10:7897"
git config --global https.proxy "http://192.168.1.10:7897"
```

然后重新加载：

```bash
source ~/.bashrc
```

### 方式三：条件代理（根据网络环境切换）

```bash
# 在 ~/.bashrc 中添加
proxy_on() {
  PROXY_HOST=192.168.1.10 HTTP_PORT=7897 SOCKS_PORT=7897 source /usr/local/bin/proxyctl on
  echo "✅ 代理已启用"
}

proxy_off() {
  source /usr/local/bin/proxyctl off
  echo "❌ 代理已关闭"
}

# 别名
alias po='proxy_on'
alias pf='proxy_off'
alias ps='proxy_status'
```

使用：

```bash
po    # 启用代理
pf    # 关闭代理
ps    # 查看状态
```

## 注意事项

- `on`/`off` 命令只影响当前 shell 会话的环境变量
- Git 和 NPM 的配置是全局的，会在 `off` 时自动清除
- APT 代理需要 sudo 权限
- Docker 代理需要 sudo 权限，配置时会重启 Docker 服务
- pip 代理配置会修改 `~/.config/pip/pip.conf` 文件
- 使用 `source` 执行脚本才能使环境变量生效到当前 shell
