#!/usr/bin/env bash
set -Eeuo pipefail

CLAUDE_URL="https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md"

main() {
  echo "Downloading CLAUDE.md..."
  curl -fsSL -o CLAUDE.md "$CLAUDE_URL"

  ln -sfn ./CLAUDE.md AGENTS.md

  echo "Done."
  echo "  CLAUDE.md <- $CLAUDE_URL"
  echo "  AGENTS.md -> ./CLAUDE.md"
}

main "$@"
