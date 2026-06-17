#!/usr/bin/env bash

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

target_shell_disable() {
  unset http_proxy https_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  unset no_proxy NO_PROXY
}

target_git_enable() {
  git config --global http.proxy "$HTTP_PROXY_URL"
  git config --global https.proxy "$HTTP_PROXY_URL"
}

target_git_disable() {
  git config --global --unset http.proxy 2>/dev/null || true
  git config --global --unset https.proxy 2>/dev/null || true
}

target_git_status() {
  echo "Git:"
  git config --global --get http.proxy || true
  git config --global --get https.proxy || true
}

target_npm_enable() {
  if command -v npm >/dev/null 2>&1; then
    npm config set proxy "$HTTP_PROXY_URL" >/dev/null
    npm config set https-proxy "$HTTP_PROXY_URL" >/dev/null
  fi
}

target_npm_disable() {
  if command -v npm >/dev/null 2>&1; then
    npm config delete proxy >/dev/null 2>&1 || true
    npm config delete https-proxy >/dev/null 2>&1 || true
  fi
}

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

target_apt_status() {
  echo "APT:"
  if [ -f "$APT_PROXY_FILE" ]; then
    cat "$APT_PROXY_FILE"
  else
    echo "No apt proxy config."
  fi
}

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
  echo "Docker proxy disabled."
}

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

target_pip_status() {
  echo "pip:"
  if [ -f "$PIP_CONFIG_FILE" ]; then
    cat "$PIP_CONFIG_FILE"
  else
    echo "No pip proxy config."
  fi
}
