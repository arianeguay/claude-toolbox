---
name: clean-worktree
description: Use when cleaning up stale git worktrees and local branches after MRs/PRs merge — worktrees whose remote branch was deleted on merge, merged branches with no worktree, backup/* safety branches, and dangling worktree records. Triggers - /clean-worktree, "clean my worktrees", "remove stale branches", "nettoie les worktrees/branches".
---

# clean-worktree

## Overview

Removes stale worktrees and local branches left behind after MRs merge. Presents a full preview, asks for **one** go/no-go, then deletes everything approved.

**Core insight:** When a repo **squashes on merge**, `git branch --merged <base>` detects *nothing* (the squash commit has a different SHA) and `git branch -d` refuses ("not fully merged"). The reliable "this branch was merged" signal is its **upstream going `[gone]`** after `git fetch --prune` — GitHub/GitLab delete the source branch on merge when "delete branch on merge" is enabled. So: prune first, target `[gone]` upstreams, delete with `-D`. The preview + single confirmation is what makes the force-delete safe.

## What gets cleaned

1. **Merged worktrees** — worktrees whose branch upstream is `[gone]` after prune.
2. **Merged branches, no worktree** — local branches with `[gone]` upstream and no attached worktree.
3. **`backup/*` branches** — local branches under `backup/` (temporary safety nets).
4. **Dangling worktree records** — `git worktree prune` for worktrees whose directory was deleted manually.

## NEVER touch (hard guards)

- `develop`, `master`, `main`
- The **current** branch and the **current** worktree (`git rev-parse --show-toplevel`)
- The **main checkout** (first entry of `git worktree list`)
- `gitbutler/workspace` and anything under `gitbutler/*`
- Any worktree with **uncommitted changes** — exclude it, warn loudly, never `--force`

## Procedure

### 1. Prune remotes (this is what flips merged branches to `[gone]`)

```bash
git fetch --prune
```

### 2. Detect candidates

```bash
MAIN=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
CUR=$(git rev-parse --show-toplevel)

# Worktrees whose branch upstream is now [gone] (merged), excluding main/current/gitbutler
git worktree list --porcelain | awk '/^worktree /{wt=$2} /^branch /{br=$2; sub("refs/heads/","",br); print wt"\t"br}'

# Per branch, the gone signal:
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/   # look for [gone]

# backup/* branches
git for-each-ref --format='%(refname:short)' 'refs/heads/backup/*'

# dangling worktree records
git worktree prune --dry-run -v
```

A branch is a **merged candidate** when its `upstream:track` is `[gone]`. Cross-check each candidate worktree for dirtiness before listing it as removable:

```bash
git -C "<worktree-path>" status --porcelain   # non-empty → DIRTY, exclude + warn
```

### 3. Present the preview, then ask ONCE

Show grouped lists with the last commit subject per branch so the user can sanity-check. Example shape:

```
Worktrees to remove (merged, remote gone):
  .worktrees/feature-login-rework  feature-login-rework  "test(auth): cover token refresh edge cases…"
Branches to delete (merged, no worktree):
  (none)
backup/* branches to delete:
  backup/feature-search-20260601-163329  "fix(search): debounce query input…"
Dangling worktree records to prune:
  (none)

Skipped (dirty — left untouched):
  .worktrees/feature-export  (3 uncommitted files)

Proceed? [y/N]
```

Use **AskUserQuestion** or a plain yes/no. One confirmation for the whole batch. If the user says no, stop — change nothing.

### 4. Execute (only after approval)

```bash
# Worktrees: remove the worktree, then force-delete its now-detached branch
git worktree remove "<worktree-path>"        # NO --force; dirty ones were already excluded
git branch -D "<branch>"                       # -D because squash-merge → -d would refuse

# Bare merged branches:
git branch -D "<branch>"

# backup/* branches:
git branch -D "backup/<name>"

# Dangling records:
git worktree prune
```

### 5. Report

Print what was removed and what was skipped (and why). Re-run `git worktree list` to confirm.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Using `git branch --merged <base>` to find merged branches | Squash-merge defeats it. Use `[gone]` upstream after `git fetch --prune`. |
| `git branch -d` then giving up on "not fully merged" | Use `-D` — the preview/confirm is the safety, not git's merge check. |
| Skipping `git fetch --prune` | Without it upstreams never flip to `[gone]` and nothing is detected. |
| `git worktree remove --force` on dirty trees | Never. Exclude dirty worktrees and warn; the user decides manually. |
| Deleting `gitbutler/workspace` or `backup/*` you didn't list | Hard guards. `gitbutler/*` is internal; only delete `backup/*` when shown in preview. |
| Removing the current worktree / main checkout | Always exclude `git rev-parse --show-toplevel` and the first `git worktree list` entry. |

## Notes

- A `[gone]` upstream normally means *merged then source-branch-deleted*. It can in rare cases mean *remote deleted without merging*. The preview (branch name + last commit) is the human check; that's why this skill never runs fully unattended.
- Works from any repo — a generic git worktree cleaner for the squash-merge + `.worktrees/<branch>` workflow. If your remote doesn't delete source branches on merge, `[gone]` never appears and nothing is detected — enable "delete branch on merge" (or delete the remote branch yourself) for this to work.