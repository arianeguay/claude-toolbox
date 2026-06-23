#!/usr/bin/env bash
# Symlink the skills from this repo into ~/.claude so Claude Code picks them up.
# Idempotent. The repo stays the source of truth; edit here, changes are live immediately.
#
#   ./install.sh              # link (refuses to clobber a real dir/file that isn't already our symlink)
#   ./install.sh --force      # back up any conflicting real path to <path>.bak-<ts>, then link
#   ./install.sh --uninstall  # remove only the symlinks we created
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
FORCE=0; UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# Auto-discover every skill in skills/ — no hardcoded list to keep in sync.
LINKS=()
for dir in "$REPO"/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  LINKS+=("skills/$name:skills/$name")
done

link_one() {
  local src="$REPO/$1" dest="$CLAUDE/$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    ln -sfn "$src" "$dest"; echo "  ✓ relinked  $dest"
  elif [ -e "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      local bak="$dest.bak-$(date +%Y%m%d%H%M%S)"
      mv "$dest" "$bak"; ln -s "$src" "$dest"
      echo "  ✓ linked    $dest  (backed up old → $bak)"
    else
      echo "  ⚠ skipped   $dest already exists and is not our symlink (use --force to back up + link)"
    fi
  else
    ln -s "$src" "$dest"; echo "  ✓ linked    $dest"
  fi
}

unlink_one() {
  local src="$REPO/$1" dest="$CLAUDE/$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    rm "$dest"; echo "  ✓ removed   $dest"
  else
    echo "  – left      $dest (not our symlink)"
  fi
}

echo "Repo:    $REPO"
echo "Target:  $CLAUDE"
echo
if [ "$UNINSTALL" -eq 1 ]; then
  echo "Removing symlinks…"
  for pair in "${LINKS[@]}"; do unlink_one "${pair%%:*}" "${pair##*:}"; done
else
  echo "Linking skills into ~/.claude…"
  for pair in "${LINKS[@]}"; do link_one "${pair%%:*}" "${pair##*:}"; done
  echo
  echo "Done. Restart Claude Code (or start a new session) to pick up the skills."
fi
