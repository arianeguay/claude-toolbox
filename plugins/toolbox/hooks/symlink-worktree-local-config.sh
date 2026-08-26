#!/usr/bin/env bash
# SessionStart + PostToolUse(Bash) hook.
#
# Symlinks local-only config (gitignored, never committed) from the main repo
# into every registered worktree, so a worktree session sees the same .env,
# CLAUDE.local.md, agents and rules as the main checkout.
#
# Symlink rather than copy: one source of truth, so editing the file in a
# worktree updates the main repo instead of silently drifting.
#
# Wired to PostToolUse(Bash) as well as SessionStart because `git worktree add`
# from a terminal or another session never fires SessionStart here.
#
# Idempotent and silent: only ever creates missing links.

set -e

COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || true)"
[ -z "$COMMON_DIR" ] && exit 0

case "$COMMON_DIR" in
  /*) ABS_COMMON_DIR="$COMMON_DIR" ;;
  *)  ABS_COMMON_DIR="$(pwd)/$COMMON_DIR" ;;
esac

MAIN_REPO="$(cd "$ABS_COMMON_DIR/.." 2>/dev/null && pwd || true)"
[ -z "$MAIN_REPO" ] && exit 0

# Cross-project defaults. Deliberately an allowlist: enumerating gitignored
# files instead sweeps up build artifacts, .DS_Store and the worktree root.
PATHS_TO_LINK=(
  "CLAUDE.local.md"
  ".claude/settings.local.json"
  ".claude/agents"
  ".claude/rules"
  ".cursor"
  ".vscode/settings.json"
  ".envrc"
  ".env"
  ".env.local"
  ".env.development.local"
  ".env.test.local"
  ".env.production.local"
)

# Per-repo additions, one path per line, # for comments.
LINK_CONFIG="$MAIN_REPO/.claude/worktree-link"
if [ -f "$LINK_CONFIG" ]; then
  while IFS= read -r rel || [ -n "$rel" ]; do
    rel="${rel%"${rel##*[![:space:]]}"}"
    case "$rel" in
      ''|'#'*) continue ;;
      /*|*..*) continue ;;  # absolute paths and traversal escape the repo
    esac
    PATHS_TO_LINK+=("$rel")
  done < "$LINK_CONFIG"
fi

git -C "$MAIN_REPO" worktree list --porcelain | awk '/^worktree / { print $2 }' | while read -r wt; do
  [ "$wt" = "$MAIN_REPO" ] && continue
  [ ! -d "$wt" ] && continue

  for rel in "${PATHS_TO_LINK[@]}"; do
    src="$MAIN_REPO/$rel"
    dst="$wt/$rel"
    [ ! -e "$src" ] && continue
    [ -e "$dst" ] && continue
    # A worktree living under src (e.g. .worktrees/) would link into itself.
    case "$wt/" in "$src"/*) continue ;; esac
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
  done
done

exit 0
