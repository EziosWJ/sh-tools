#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/EziosWJ/sh-tools/master}"

if [[ -f "$SCRIPT_DIR/../skills/providers/karpathy.sh" ]]; then
  bash "$SCRIPT_DIR/../skills/providers/karpathy.sh" "$@"
  exit 0
fi

bash <(curl -fsSL "$REPO_RAW_BASE/skills/providers/karpathy.sh") "$@"
