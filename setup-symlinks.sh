#!/usr/bin/env bash
# Symlink this repo's configs into ~/.config so tools pick them up.
# Idempotent: re-running replaces existing symlinks.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "SKIP  $dst already exists and is not a symlink"
    return
  fi
  ln -sfn "$src" "$dst"
  echo "link  $dst -> $src"
}

link "$REPO/nvim"                     "$CONFIG/nvim"
link "$REPO/tmux"                     "$CONFIG/tmux"
link "$REPO/AGENTS.global.md"         "$CONFIG/opencode/AGENTS.md"
link "$REPO/skills/spec-driven-dev"   "$CONFIG/opencode/skills/spec-driven-dev"

echo "Done."
