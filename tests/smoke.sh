#!/usr/bin/env bash
# 使用临时目录和本地下载替身；不会安装软件或连接外部网络。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/sh-tools-test.XXXXXX)"
cleanup() {
  if [[ -n "${TMUX_TEST_BINARY:-}" ]]; then
    env -u TMUX "$TMUX_TEST_BINARY" -L "$TMUX_TEST_SOCKET" kill-server 2>/dev/null || true
  fi
  rm -rf -- "$WORK"
}
trap cleanup EXIT
export TMUX_TEST_BINARY="$(command -v tmux || true)"
export TMUX_TEST_SOCKET="${WORK##*/}"
mkdir -p "$WORK/bin" "$WORK/project" "$WORK/remote"
cp "$ROOT/tests/fixtures/curl" "$WORK/bin/curl"
cp "$ROOT/tests/fixtures/tmux" "$WORK/bin/tmux"
cp "$ROOT/tests/fixtures/dpkg" "$WORK/bin/dpkg"
cp "$ROOT/tests/fixtures/deny-install" "$WORK/bin/apt"
cp "$ROOT/tests/fixtures/deny-install" "$WORK/bin/sudo"
chmod +x "$WORK/bin/curl" "$WORK/bin/tmux" "$WORK/bin/dpkg" "$WORK/bin/apt" "$WORK/bin/sudo"
export PATH="$WORK/bin:$PATH"
export SH_TOOLS_TEST_REPO="$ROOT"
export REPO_RAW_BASE=https://sh-tools.test
export SH_TOOLS_AGENTS_RUNTIME_DIR="$WORK/agents"
export SH_TOOLS_SKILLS_RUNTIME_DIR="$WORK/skills"
export ADD_TMUX_HELP_RUNTIME_DIR="$WORK/tmux"
export ADD_TMUX_HELP_BIN_DIR="$WORK/bin"
export SH_TOOLS_CONFIG_DIR="$WORK/config"
export ADD_TMUX_HELP_RC_DIR="$WORK/shell"
OUT="$WORK/output"

count() {
  local actual
  actual="$(grep -Fc "$1" "$OUT" || true)"
  [[ "$actual" == "$2" ]] || {
    printf 'FAIL: %s expected=%s actual=%s\n' "$1" "$2" "$actual" >&2
    cat "$OUT" >&2
    exit 1
  }
}

bash "$ROOT/sh-tools.sh" list >"$OUT"
grep -Fxq 'mihomo' "$OUT"
bash "$ROOT/mihomo/mihomo.sh" --help >"$OUT"
grep -Fq 'bash mihomo.sh setup' "$OUT"
grep -Fq 'show-config' "$OUT"

if printf '7\n0\n' | timeout 5 bash "$ROOT/mihomo/mihomo.sh" >"$OUT" 2>&1; then
  :
fi
! grep -Fq 'status: command not found' "$OUT"

menu() {
  local input="$1"
  shift
  printf '%s' "$input" | timeout 15 bash "$@" >"$OUT" 2>&1
}

while IFS= read -r file; do bash -n "$file"; done < <(find "$ROOT" -name '*.sh' -not -path '*/.git/*')
menu $'bad\n3\n1\n6\n0\n0\n0\n' "$ROOT/sh-tools.sh"
count '请选择工具：' 3
count '请选择 agent 工具：' 2
count '请选择 Codex 操作：' 2

for provider in codex claude-code opencode pi-agent hermes; do
  choice=6
  [[ "$provider" == hermes ]] && choice=4
  printf -v input 'bad\n%s\n0\n' "$choice"
  menu "$input" "$ROOT/agents/providers/$provider.sh"
  count '输入无效。' 1
  count '卸载建议：' 1
done
menu $'7\n5\nmissing\n0\n0\n' "$ROOT/agents/providers/claude-code.sh"
count '请选择 Claude Code 配置操作：' 2
count '配置操作失败' 1

cd "$WORK/project"
menu $'1\n1\n0\n' "$ROOT/skills/skills.sh"
count '请选择 skills provider：' 3
count '已初始化项目规则' 1
count '已存在' 1
[[ "$(cat CLAUDE.md)" == '@AGENTS.md' ]]
if bash "$ROOT/sh-tools.sh" skills agents-template "$WORK/project" >"$OUT" 2>&1; then
  echo 'FAIL: direct failure returned success' >&2; exit 1
fi

# mirror 只使用下载失败替身，保证不会执行改源或 sudo。
menu $'2\ny\n0\n' "$ROOT/init-Linux/init-linux.sh"
count '请选择要执行的操作：' 2
count '操作失败' 1

menu $'3\n1\n2\n0\n0\n' "$ROOT/init-Linux/init-linux.sh"
count '请选择可选依赖组：' 3
count '请选择要执行的操作：' 2
export SH_TOOLS_TEST_MISSING_PACKAGES=1
menu $'3\n0\n' "$ROOT/init-Linux/init-linux.sh"
count '操作失败' 1
count '安装完成。' 0
unset SH_TOOLS_TEST_MISSING_PACKAGES

# 模拟无仓库的进程替换入口，检验子进程仍能读取脚本和返回菜单。
printf '3\n1\n6\n0\n0\n0\n' | timeout 15 bash -c 'bash <(cat "$1/sh-tools.sh")' _ "$ROOT" >"$OUT" 2>&1
count '请选择工具：' 2
count '请选择 Codex 操作：' 2
export SH_TOOLS_TEST_FAIL_URL=https://sh-tools.test/agents/providers/codex.sh
cp "$ROOT/agents/agents.sh" "$WORK/remote/agents.sh"
menu $'1\n0\n' "$WORK/remote/agents.sh"
count '请选择 agent 工具：' 2
count '操作失败' 1
unset SH_TOOLS_TEST_FAIL_URL

for provider in codex claude-code opencode pi-agent hermes; do
  choice=6
  [[ "$provider" == hermes ]] && choice=4
  printf '%s\n0\n' "$choice" | timeout 15 bash -c 'bash <(cat "$1/agents/providers/$2.sh")' _ "$ROOT" "$provider" >"$OUT" 2>&1
  count '卸载建议：' 1
  count '返回上一级' 2
done
printf '2\ny\n0\n' | timeout 15 bash -c 'bash <(cat "$1/init-Linux/init-linux.sh")' _ "$ROOT" >"$OUT" 2>&1
count '请选择要执行的操作：' 2
count '操作失败' 1
printf '2\n1\n0\n0\n' | timeout 15 bash -c 'bash <(cat "$1/add-tmux-help/add-tmux-help.sh")' _ "$ROOT" >"$OUT" 2>&1
count 'tmux 工具' 2
count '选择帮助分类：' 2

menu $'4\n4\n0\n0\n' "$ROOT/wireguard/wg-client.sh"
count 'WireGuard 工控机端管理' 2
count '==== 服务控制' 2

# 安装到临时目录，可重复安装；shell 配置不参与测试。
bash "$ROOT/add-tmux-help/add-tmux-help.sh" install >"$OUT"
bash "$ROOT/add-tmux-help/add-tmux-help.sh" install >>"$OUT"
tmux-help session >"$OUT"
count '会话管理 (Session)' 1
menu $'1\n2\n0\n' "$WORK/bin/tmux-help" -i
count '选择帮助分类：' 3
menu $'2\n1\n0\n0\n' "$ROOT/add-tmux-help/add-tmux-help.sh"
count 'tmux 工具' 2

if [[ -n "$TMUX_TEST_BINARY" ]]; then
  # 真正的 tmux，使用独立 socket；绝不操作默认服务中的会话。
  env -u TMUX "$WORK/bin/tmux-session" create dev "$WORK"
  env -u TMUX "$WORK/bin/tmux-session" create dev-extra "$WORK"
  env -u TMUX "$WORK/bin/tmux-session" rename dev work
  if env -u TMUX "$WORK/bin/tmux-session" rename de wrong >"$OUT" 2>&1; then
    echo 'FAIL: session target used prefix matching' >&2; exit 1
  fi
  menu $'1\n3\n0\n4\n0\n5\n0\n0\n' "$WORK/bin/tmux-session"
  count 'tmux 会话管理' 5
  printf 'n\n' | "$WORK/bin/tmux-session" kill work
  tmux has-session -t '=work'
  printf 'y\n' | "$WORK/bin/tmux-session" kill work
  if tmux has-session -t '=work' 2>/dev/null; then exit 1; fi
  tmux has-session -t '=dev-extra'
  if command -v fzf >/dev/null && command -v python3 >/dev/null; then
    python3 "$ROOT/tests/tmux-ui.py" "$WORK/bin/tmux-session" "$WORK/bin/tmux"
  fi
else
  echo 'SKIP: real tmux tests (tmux not installed)'
fi
bash "$ROOT/add-tmux-help/add-tmux-help.sh" uninstall >"$OUT"
[[ ! -e "$WORK/bin/tmux-help" && ! -e "$WORK/bin/tmux-session" ]]
echo 'PASS: syntax, nested menus, failure recovery, remote entry, project rules, tmux commands'
