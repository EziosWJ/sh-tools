#!/usr/bin/env bash

PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
HTTP_PORT="${HTTP_PORT:-7890}"
SOCKS_PORT="${SOCKS_PORT:-7890}"

HTTP_PROXY_URL="http://${PROXY_HOST}:${HTTP_PORT}"
SOCKS_PROXY_URL="socks5://${PROXY_HOST}:${SOCKS_PORT}"

APT_PROXY_FILE="/etc/apt/apt.conf.d/95proxies"

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
}

case "$1" in
  on) on ;;
  off) off ;;
  apt-on) apt_on ;;
  apt-off) apt_off ;;
  status) status ;;
  *)
    echo "Usage:"
    echo "  proxyctl on"
    echo "  proxyctl off"
    echo "  proxyctl apt-on"
    echo "  proxyctl apt-off"
    echo "  proxyctl status"
    echo
    echo "Optional:"
    echo "  PROXY_HOST=127.0.0.1 HTTP_PORT=7890 SOCKS_PORT=7890 proxyctl on"
    ;;
esac
