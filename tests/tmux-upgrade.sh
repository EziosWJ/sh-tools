#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/sh-tools-upgrade.XXXXXX)"
trap 'rm -rf -- "$WORK"' EXIT
export ADD_TMUX_HELP_BIN_DIR="$WORK/bin"
export ADD_TMUX_HELP_RUNTIME_DIR="$WORK/runtime"
export ADD_TMUX_HELP_RC_DIR="$WORK/shell"
mkdir -p "$WORK/bin" "$WORK/shell"
for rc in .bashrc .zshrc; do
  {
    printf '# unrelated-before\n'
    for module in tmux-help tmux-session; do
      printf '# >>> %s >>>\nsource "%s/lib/utils.sh"\nsource "%s/lib/%s.sh"\n%s() { %s_main "$@"; }\n# <<< %s <<<\n' \
        "$module" "$ROOT/add-tmux-help" "$ROOT/add-tmux-help" "$module" "$module" "${module//-/_}" "$module"
    done
    printf '# unrelated-after\n'
  } > "$WORK/shell/$rc"
done
# 检验安装后 zsh 通过命令名运行时，不再直接执行 Bash 函数。
bash "$ROOT/add-tmux-help/add-tmux-help.sh" install
printf '0\n' | zsh -f -c 'source "$1"; tmux-session' _ "$WORK/shell/.zshrc" > "$WORK/zsh-output" 2>&1
if grep -q 'no coprocess' "$WORK/zsh-output"; then
  cat "$WORK/zsh-output"; exit 1
fi
grep -q 'tmux 会话管理' "$WORK/zsh-output"
grep -qFx '# unrelated-before' "$WORK/shell/.zshrc"
grep -qFx '# unrelated-after' "$WORK/shell/.zshrc"
printf '0\n' | bash -c 'source "$1"; tmux-session' _ "$WORK/shell/.bashrc" > "$WORK/bash-output" 2>&1
legacy() {
  local module
  for module in tmux-help tmux-session; do
    printf '#!/usr/bin/env bash\nsource "%s/lib/utils.sh"\nsource "%s/lib/%s.sh"\n%s_main "$@"\n' \
      "$ROOT/add-tmux-help" "$ROOT/add-tmux-help" "$module" "${module//-/_}" > "$WORK/bin/$module"
  done
}
legacy
cp "$WORK/bin/tmux-help" "$WORK/original"
# 重现用户的卸载 → 安装；旧命令必须被识别并保留备份。
bash "$ROOT/add-tmux-help/add-tmux-help.sh" uninstall
bash "$ROOT/add-tmux-help/add-tmux-help.sh" install
grep -qFx '# sh-tools tmux command' "$WORK/bin/tmux-help"
backup="$(find "$WORK/bin" -path '*/.sh-tools-backup.*/tmux-help' -type f -print -quit)"
[[ -n "$backup" ]] && cmp "$WORK/original" "$backup"
# 直接安装也能替换已知旧命令。
legacy
bash "$ROOT/add-tmux-help/add-tmux-help.sh" install
grep -qFx '# sh-tools tmux command' "$WORK/bin/tmux-session"
# 未知命令不能被覆盖，且不能先覆盖另一个可识别命令。
legacy
printf 'unrelated command\n' > "$WORK/bin/tmux-session"
if bash "$ROOT/add-tmux-help/add-tmux-help.sh" install; then
  echo 'FAIL: unrelated command overwritten' >&2; exit 1
fi
cmp "$WORK/original" "$WORK/bin/tmux-help"
grep -qFx 'unrelated command' "$WORK/bin/tmux-session"
echo 'PASS: legacy uninstall/install, backup, direct upgrade, unrelated file protection'
