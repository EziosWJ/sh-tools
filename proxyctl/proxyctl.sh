#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/targets.sh" ]]; then
  source "$SCRIPT_DIR/lib/targets.sh"
fi

PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
HTTP_PORT="${HTTP_PORT:-7890}"
SOCKS_PORT="${SOCKS_PORT:-7890}"

HTTP_PROXY_URL="http://${PROXY_HOST}:${HTTP_PORT}"
SOCKS_PROXY_URL="socks5://${PROXY_HOST}:${SOCKS_PORT}"

APT_PROXY_FILE="/etc/apt/apt.conf.d/95proxies"
DOCKER_PROXY_DIR="/etc/systemd/system/docker.service.d"
DOCKER_PROXY_FILE="${DOCKER_PROXY_DIR}/proxy.conf"
PIP_CONFIG_FILE="${HOME}/.config/pip/pip.conf"
PIP_CONFIG_DIR="${HOME}/.config/pip"

# Logging functions
log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }

if ! declare -F target_shell_enable >/dev/null 2>&1; then
  target_shell_enable() {
    export http_proxy="$HTTP_PROXY_URL"
    export https_proxy="$HTTP_PROXY_URL"
    export all_proxy="$SOCKS_PROXY_URL"
    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$https_proxy"
    export ALL_PROXY="$all_proxy"
    export no_proxy="localhost,127.0.0.1,::1"
    export NO_PROXY="$no_proxy"
  }
fi

if ! declare -F target_shell_disable >/dev/null 2>&1; then
  target_shell_disable() {
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy NO_PROXY
  }
fi

if ! declare -F target_git_enable >/dev/null 2>&1; then
  target_git_enable() {
    git config --global http.proxy "$HTTP_PROXY_URL"
    git config --global https.proxy "$HTTP_PROXY_URL"
  }
fi

if ! declare -F target_git_disable >/dev/null 2>&1; then
  target_git_disable() {
    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true
  }
fi

if ! declare -F target_git_status >/dev/null 2>&1; then
  target_git_status() {
    echo "Git:"
    git config --global --get http.proxy || true
    git config --global --get https.proxy || true
  }
fi

if ! declare -F target_npm_enable >/dev/null 2>&1; then
  target_npm_enable() {
    if command -v npm >/dev/null 2>&1; then
      npm config set proxy "$HTTP_PROXY_URL" >/dev/null
      npm config set https-proxy "$HTTP_PROXY_URL" >/dev/null
    fi
  }
fi

if ! declare -F target_npm_disable >/dev/null 2>&1; then
  target_npm_disable() {
    if command -v npm >/dev/null 2>&1; then
      npm config delete proxy >/dev/null 2>&1 || true
      npm config delete https-proxy >/dev/null 2>&1 || true
    fi
  }
fi

if ! declare -F target_npm_status >/dev/null 2>&1; then
  target_npm_status() {
    echo "NPM:"
    if command -v npm >/dev/null 2>&1; then
      local npm_proxy
      local npm_https_proxy
      npm_proxy=$(npm config get proxy)
      npm_https_proxy=$(npm config get https-proxy)
      if [ -n "$npm_proxy" ] || [ -n "$npm_https_proxy" ]; then
        echo "  proxy=$npm_proxy"
        echo "  https-proxy=$npm_https_proxy"
      else
        echo "No npm proxy config."
      fi
    fi
  }
fi

if ! declare -F target_apt_enable >/dev/null 2>&1; then
  target_apt_enable() {
    if ! echo "Acquire::http::Proxy \"${HTTP_PROXY_URL}\";" | sudo tee "$APT_PROXY_FILE" >/dev/null; then
      log_error "Failed to set APT proxy. Please check sudo permissions."
      return 1
    fi
    if ! echo "Acquire::https::Proxy \"${HTTP_PROXY_URL}\";" | sudo tee -a "$APT_PROXY_FILE" >/dev/null; then
      log_error "Failed to set APT proxy. Please check sudo permissions."
      return 1
    fi
    echo "APT proxy enabled: $HTTP_PROXY_URL"
  }
fi

if ! declare -F target_apt_disable >/dev/null 2>&1; then
  target_apt_disable() {
    if ! command -v sudo >/dev/null 2>&1; then
      log_error "sudo is not installed."
      return 1
    fi
    if [ -f "$APT_PROXY_FILE" ]; then
      if grep -q "Acquire::http::Proxy\|Acquire::https::Proxy" "$APT_PROXY_FILE"; then
        sed -i '/Acquire::http::Proxy/d' "$APT_PROXY_FILE"
        sed -i '/Acquire::https::Proxy/d' "$APT_PROXY_FILE"
        if [ ! -s "$APT_PROXY_FILE" ]; then
          sudo rm -f "$APT_PROXY_FILE"
        fi
      fi
    fi
    echo "APT proxy disabled."
  }
fi

if ! declare -F target_apt_status >/dev/null 2>&1; then
  target_apt_status() {
    echo "APT:"
    if [ -f "$APT_PROXY_FILE" ]; then
      cat "$APT_PROXY_FILE"
    else
      echo "No apt proxy config."
    fi
  }
fi

if ! declare -F target_docker_enable >/dev/null 2>&1; then
  target_docker_enable() {
    if ! command -v docker >/dev/null 2>&1; then
      log_error "Docker is not installed."
      return 1
    fi
    sudo mkdir -p "$DOCKER_PROXY_DIR"
    sudo tee "$DOCKER_PROXY_FILE" >/dev/null <<EOF
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY_URL}"
Environment="HTTPS_PROXY=${HTTP_PROXY_URL}"
Environment="ALL_PROXY=${SOCKS_PROXY_URL}"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF
    if ! sudo systemctl daemon-reload; then
      log_error "Failed to reload systemd daemon."
      return 1
    fi
    if ! sudo systemctl restart docker; then
      log_error "Docker restart failed. Please restart manually."
      return 1
    fi
    echo "Docker proxy enabled: $HTTP_PROXY_URL"
  }
fi

if ! declare -F target_docker_disable >/dev/null 2>&1; then
  target_docker_disable() {
    if ! command -v docker >/dev/null 2>&1; then
      log_error "Docker is not installed."
      return 1
    fi
    if [ -f "$DOCKER_PROXY_FILE" ]; then
      if grep -q "Environment.*_PROXY" "$DOCKER_PROXY_FILE"; then
        sed -i '/Environment.*_PROXY/d' "$DOCKER_PROXY_FILE"
        if [ ! -s "$DOCKER_PROXY_FILE" ]; then
          sudo rm -f "$DOCKER_PROXY_FILE"
        fi
      fi
    fi
    if ! sudo systemctl daemon-reload; then
      log_error "Failed to reload systemd daemon."
      return 1
    fi
    if ! sudo systemctl restart docker; then
      log_error "Docker restart failed. Please restart manually."
      return 1
    fi
    echo "Docker proxy disabled: $HTTP_PROXY_URL"
  }
fi

if ! declare -F target_docker_status >/dev/null 2>&1; then
  target_docker_status() {
    if ! command -v docker >/dev/null 2>&1; then
      log_error "Docker is not installed."
      return 1
    fi
    echo "Docker:"
    if [ -f "$DOCKER_PROXY_FILE" ]; then
      cat "$DOCKER_PROXY_FILE"
    else
      echo "No Docker proxy config."
    fi
  }
fi

if ! declare -F target_pip_enable >/dev/null 2>&1; then
  target_pip_enable() {
    if ! command -v pip >/dev/null 2>&1; then
      log_error "pip is not installed."
      return 1
    fi
    mkdir -p "$PIP_CONFIG_DIR"
    tee "$PIP_CONFIG_FILE" >/dev/null <<EOF
[global]
proxy = ${HTTP_PROXY_URL}
EOF
    echo "pip proxy enabled: $HTTP_PROXY_URL"
  }
fi

if ! declare -F target_pip_disable >/dev/null 2>&1; then
  target_pip_disable() {
    if ! command -v pip >/dev/null 2>&1; then
      log_error "pip is not installed."
      return 1
    fi
    if [ -f "$PIP_CONFIG_FILE" ]; then
      if grep -q "^proxy" "$PIP_CONFIG_FILE"; then
        sed -i '/^proxy/d' "$PIP_CONFIG_FILE"
        if [ ! -s "$PIP_CONFIG_FILE" ]; then
          rm -f "$PIP_CONFIG_FILE"
        fi
      fi
    fi
    echo "pip proxy disabled."
  }
fi

if ! declare -F target_pip_status >/dev/null 2>&1; then
  target_pip_status() {
    echo "pip:"
    if [ -f "$PIP_CONFIG_FILE" ]; then
      cat "$PIP_CONFIG_FILE"
    else
      echo "No pip proxy config."
    fi
  }
fi

target_enable() {
  local target="$1"
  "target_${target}_enable"
}

target_disable() {
  local target="$1"
  "target_${target}_disable"
}

target_status() {
  local target="$1"
  "target_${target}_status"
}

on() {
  local target
  local targets=(shell git npm pip)

  for target in "${targets[@]}"; do
    if [[ "$target" == "pip" ]]; then
      target_enable "$target" || true
    else
      target_enable "$target"
    fi
  done

  echo "Proxy enabled for current shell:"
  echo "  http_proxy=$http_proxy"
  echo "  https_proxy=$https_proxy"
  echo "  all_proxy=$all_proxy"
  if command -v pip >/dev/null 2>&1; then
    echo "  pip proxy=$HTTP_PROXY_URL"
  fi
}

off() {
  local target
  local targets=(shell git npm pip)

  for target in "${targets[@]}"; do
    if [[ "$target" == "pip" ]]; then
      target_disable "$target" || true
    else
      target_disable "$target"
    fi
  done

  echo "Proxy disabled for current shell, git, npm and pip."
}

apt_on() { target_enable apt; }
apt_off() { target_disable apt; }
docker_on() { target_enable docker; }
docker_off() { target_disable docker; }
docker_status() { target_status docker; }
pip_on() { target_enable pip; }
pip_off() { target_disable pip; }
pip_status() { target_status pip; }

status() {
  echo "Environment:"
  env | grep -i '_proxy' || true

  echo
  target_status git
  echo
  target_status npm
  echo
  target_status apt
  echo
  target_status docker
  echo
  target_status pip
}

case "$1" in
  on) on ;;
  off) off ;;
  apt-on) apt_on ;;
  apt-off) apt_off ;;
  docker-on) docker_on ;;
  docker-off) docker_off ;;
  docker-status) docker_status ;;
  pip-on) pip_on ;;
  pip-off) pip_off ;;
  pip-status) pip_status ;;
  status) status ;;
  *)
    echo "Usage:"
    echo "  proxyctl on"
    echo "  proxyctl off"
    echo "  proxyctl apt-on"
    echo "  proxyctl apt-off"
    echo "  proxyctl docker-on"
    echo "  proxyctl docker-off"
    echo "  proxyctl docker-status"
    echo "  proxyctl pip-on"
    echo "  proxyctl pip-off"
    echo "  proxyctl pip-status"
    echo "  proxyctl status"
    echo
    echo "Optional:"
    echo "  PROXY_HOST=127.0.0.1 HTTP_PORT=7890 SOCKS_PORT=7890 proxyctl on"
    ;;
esac
