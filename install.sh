#!/usr/bin/env bash
# Symlink the skills from this repo into ~/.claude so Claude Code picks them up.
# Idempotent. The repo stays the source of truth; edit here, changes are live immediately.
#
#   ./install.sh                                  # link all, bare names (refuses to clobber a real dir/file that isn't already our symlink)
#   ./install.sh --force                          # back up any conflicting real path to <path>.bak-<ts>, then link
#   ./install.sh --uninstall                      # remove only the symlinks we created (bare names)
#   ./install.sh --prefix my --only mr-description,git-clean-history
#                                                  # COPY (not symlink) the named skills as my-<name>, rewriting the
#                                                  # SKILL.md frontmatter `name:` to match — use when a bare name
#                                                  # collides with a project's own .claude/skills/<name>. A symlink
#                                                  # alone isn't enough: Claude Code keys off the frontmatter `name:`,
#                                                  # not the directory name, so an aliased dir must carry its own name.
#                                                  # Re-run after editing an aliased skill's source — it's a copy, not live.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
FORCE=0; UNINSTALL=0; PREFIX=""; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --prefix) PREFIX="$2"; shift ;;
    --only) ONLY="$2"; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

# Auto-discover every skill in skills/ — no hardcoded list to keep in sync.
# --only filters to a comma-separated subset; --prefix names the dest link "<prefix>-<name>" instead of "<name>".
LINKS=()
for dir in "$REPO"/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$name,"* ]]; then continue; fi
  dest_name="${PREFIX:+$PREFIX-}$name"
  LINKS+=("skills/$name:skills/$dest_name")
done

link_one() {
  local src="$REPO/$1" dest="$CLAUDE/$2" dest_name="$(basename "$2")"
  mkdir -p "$(dirname "$dest")"
  if [ -n "$PREFIX" ]; then
    # Aliased: copy (not symlink) + rewrite the frontmatter `name:` so the alias
    # is self-consistent — Claude Code resolves skills by frontmatter name, not dirname.
    if [ -e "$dest" ] && [ ! -L "$dest" ] && [ "$FORCE" -ne 1 ] && [ ! -f "$dest/.toolbox-alias" ]; then
      echo "  ⚠ skipped   $dest already exists and isn't an alias we made (use --force)"
      return
    fi
    rm -rf "$dest"
    cp -r "$src" "$dest"
    sed -i '' "s/^name: .*/name: $dest_name/" "$dest/SKILL.md"
    touch "$dest/.toolbox-alias"
    echo "  ✓ aliased   $dest  (name: $dest_name)"
  elif [ -L "$dest" ]; then
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
  if [ -n "$PREFIX" ]; then
    if [ -f "$dest/.toolbox-alias" ]; then
      rm -rf "$dest"; echo "  ✓ removed   $dest"
    else
      echo "  – left      $dest (not an alias we made)"
    fi
  elif [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
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
