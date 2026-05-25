#!/usr/bin/env bash

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

on() {
  export http_proxy="$HTTP_PROXY_URL"
  export https_proxy="$HTTP_PROXY_URL"
  export all_proxy="$SOCKS_PROXY_URL"

  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export ALL_PROXY="$all_proxy"

  export no_proxy="localhost,127.0.0.1,::1"
  export NO_PROXY="$no_proxy"

  git config --global http.proxy "$HTTP_PROXY_URL"
  git config --global https.proxy "$HTTP_PROXY_URL"

  if command -v npm >/dev/null 2>&1; then
    npm config set proxy "$HTTP_PROXY_URL" >/dev/null
    npm config set https-proxy "$HTTP_PROXY_URL" >/dev/null
  fi

  pip_on

  echo "Proxy enabled for current shell:"
  echo "  http_proxy=$http_proxy"
  echo "  https_proxy=$https_proxy"
  echo "  all_proxy=$all_proxy"
}

off() {
  unset http_proxy https_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  unset no_proxy NO_PROXY

  git config --global --unset http.proxy 2>/dev/null || true
  git config --global --unset https.proxy 2>/dev/null || true

  if command -v npm >/dev/null 2>&1; then
    npm config delete proxy >/dev/null 2>&1 || true
    npm config delete https-proxy >/dev/null 2>&1 || true
  fi

  pip_off

  echo "Proxy disabled for current shell, git and npm."
}

apt_on() {
  echo "Acquire::http::Proxy \"${HTTP_PROXY_URL}\";" | sudo tee "$APT_PROXY_FILE" >/dev/null
  echo "Acquire::https::Proxy \"${HTTP_PROXY_URL}\";" | sudo tee -a "$APT_PROXY_FILE" >/dev/null
  echo "APT proxy enabled: $HTTP_PROXY_URL"
}

apt_off() {
  sudo rm -f "$APT_PROXY_FILE"
  echo "APT proxy disabled."
}

docker_on() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed."
    return 1
  fi

  sudo mkdir -p "$DOCKER_PROXY_DIR"
  sudo tee "$DOCKER_PROXY_FILE" >/dev/null << EOF
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY_URL}"
Environment="HTTPS_PROXY=${HTTP_PROXY_URL}"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF

  sudo systemctl daemon-reload
  sudo systemctl restart docker
  echo "Docker proxy enabled: $HTTP_PROXY_URL"
}

docker_off() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed."
    return 1
  fi

  sudo rm -f "$DOCKER_PROXY_FILE"
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  echo "Docker proxy disabled."
}

docker_status() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed."
    return 1
  fi

  echo "Docker proxy config:"
  if [ -f "$DOCKER_PROXY_FILE" ]; then
    cat "$DOCKER_PROXY_FILE"
  else
    echo "No Docker proxy config."
  fi
}

pip_on() {
  if ! command -v pip >/dev/null 2>&1; then
    echo "Warning: pip is not installed."
    return 1
  fi

  mkdir -p "$PIP_CONFIG_DIR"
  tee "$PIP_CONFIG_FILE" >/dev/null << EOF
[global]
proxy = ${HTTP_PROXY_URL}
EOF

  echo "pip proxy enabled: $HTTP_PROXY_URL"
}

pip_off() {
  if ! command -v pip >/dev/null 2>&1; then
    echo "Warning: pip is not installed."
    return 1
  fi

  rm -f "$PIP_CONFIG_FILE"
  echo "pip proxy disabled."
}

pip_status() {
  if ! command -v pip >/dev/null 2>&1; then
    echo "Error: pip is not installed."
    return 1
  fi

  echo "pip proxy config:"
  if [ -f "$PIP_CONFIG_FILE" ]; then
    cat "$PIP_CONFIG_FILE"
  else
    echo "No pip proxy config."
  fi
}

status() {
  echo "Environment:"
  env | grep -i '_proxy' || true

  echo
  echo "Git:"
  git config --global --get http.proxy || true
  git config --global --get https.proxy || true

  echo
  echo "NPM:"
  if command -v npm >/dev/null 2>&1; then
    npm config get proxy
    npm config get https-proxy
  fi

  echo
  echo "APT:"
  if [ -f "$APT_PROXY_FILE" ]; then
    cat "$APT_PROXY_FILE"
  else
    echo "No apt proxy config."
  fi

  echo
  echo "Docker:"
  if [ -f "$DOCKER_PROXY_FILE" ]; then
    cat "$DOCKER_PROXY_FILE"
  else
    echo "No Docker proxy config."
  fi

  echo
  echo "pip:"
  if [ -f "$PIP_CONFIG_FILE" ]; then
    cat "$PIP_CONFIG_FILE"
  else
    echo "No pip proxy config."
  fi
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
