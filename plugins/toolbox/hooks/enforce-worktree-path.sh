#!/usr/bin/env bash
# SessionStart + PostToolUse(Bash) hook.
#
# Keeps every worktree of the current repo under <repo>/.worktrees, whatever
# path the tool that created it asked for.
#
# Tools disagree on where worktrees belong: start-issue used to hardcode
# .claude/worktrees/<branch>, Claude Code's own EnterWorktree picks its own
# path, and a human types whatever they like. Rather than chase each one, the
# old location is turned into a symlink so every writer lands in the same place.
#
# Wired to PostToolUse(Bash) as well as SessionStart for the same reason as
# symlink-worktree-local-config.sh: `git worktree add` from a terminal or
# another session never fires SessionStart here.
#
# Idempotent and silent. It never moves an existing worktree: a real directory
# with content is left alone, because relocating one means repairing the
# absolute paths in .git/worktrees/*/gitdir and may strand uncommitted work.
# That is a migration, and a migration is a decision, not a hook.

set -e

COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || true)"
[ -z "$COMMON_DIR" ] && exit 0

case "$COMMON_DIR" in
  /*) ABS_COMMON_DIR="$COMMON_DIR" ;;
  *)  ABS_COMMON_DIR="$(pwd)/$COMMON_DIR" ;;
esac

MAIN_REPO="$(cd "$ABS_COMMON_DIR/.." 2>/dev/null && pwd || true)"
[ -z "$MAIN_REPO" ] && exit 0

mkdir -p "$MAIN_REPO/.worktrees"

# .git/info/exclude rather than .gitignore: no diff in the repo, nothing to
# commit, and it covers every repo the hook ever runs in. The cost is that it
# is local to this clone, so a fresh clone is bare until the hook runs once.
EXCLUDE="$ABS_COMMON_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE")"
#
# Both paths are excluded, not just .worktrees. The compatibility symlink below
# lives at .claude/worktrees, and in a repo that does not already ignore
# .claude/ it would otherwise show up as an untracked directory. A hook that
# dirties `git status` is worse than the problem it solves.
for pat in '/.worktrees/' '/.claude/worktrees'; do
  grep -qxF "$pat" "$EXCLUDE" 2>/dev/null || printf '%s\n' "$pat" >> "$EXCLUDE"
done

# Redirect the legacy location. Only when it is absent or an empty directory:
# anything else is somebody's work.
LEGACY="$MAIN_REPO/.claude/worktrees"
if [ -L "$LEGACY" ]; then
  exit 0
elif [ -d "$LEGACY" ]; then
  rmdir "$LEGACY" 2>/dev/null || exit 0   # non-empty: leave it, stay silent
elif [ -e "$LEGACY" ]; then
  exit 0                                   # a file with that name: not ours
fi

mkdir -p "$MAIN_REPO/.claude"
ln -s ../.worktrees "$LEGACY" 2>/dev/null || true

exit 0
