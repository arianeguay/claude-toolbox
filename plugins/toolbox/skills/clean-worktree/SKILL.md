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
TRUNK=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)

# Worktrees whose branch upstream is now [gone] (merged), excluding main/current/gitbutler
git worktree list --porcelain | awk '/^worktree /{wt=$2} /^branch /{br=$2; sub("refs/heads/","",br); print wt"\t"br}'

# Per branch, the gone signal:
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/   # look for [gone]

# backup/* branches
git for-each-ref --format='%(refname:short)' 'refs/heads/backup/*'

# dangling worktree records
git worktree prune --dry-run -v
```

Cross-check each candidate worktree for dirtiness before listing it as removable:

```bash
git -C "<worktree-path>" status --porcelain   # non-empty → DIRTY, exclude + warn
```

**`[gone]` is not "merged to the trunk".** GitHub/GitLab delete the source branch on ANY merge — including a merge into a now-dead intermediate base branch (a stacked-PR shape: branch B merges into branch A, and A is itself already merged, or never merges at all). Treating `[gone]` alone as "merged" force-deletes the last copy of a stranded branch. Gate every `[gone]` branch on the trunk before calling it a candidate, reusing the check `plugins/toolbox/skills/start-issue/trunk.md` already owns ("Did the work reach the trunk?" — a merge is a claim about the trunk's history, and only the trunk's history answers it):

```bash
git merge-base --is-ancestor <branch> "origin/$TRUNK" && echo REACHED || echo NOT_ANCESTOR
```

- `REACHED` → the branch's own commits are literally in the trunk's history. **Merged candidate.**
- `NOT_ANCESTOR` → not yet a verdict. A **squash**-merged branch also fails this check — the squash commit on the trunk has a new SHA, so the branch's original commits are never its ancestors. Disambiguate with the tree-level check:
  ```bash
  git diff "origin/$TRUNK"..<branch> --quiet && echo SQUASH_MERGED || echo STRANDED
  ```
  - empty diff (`SQUASH_MERGED`) → nothing the branch adds is missing from the trunk. **Merged candidate.**
  - non-empty diff (`STRANDED`) → **not a candidate.** The trunk is genuinely missing this branch's commits, and nothing will ever pull them forward — if it had a PR, that PR is merged and closed into a dead branch. List it under its own **"not on the trunk — recovery"** group instead of the deletable set:
    ```bash
    git log --oneline "origin/$TRUNK..<branch>"    # the commits the trunk is missing
    ```
    Point at the cherry-pick recovery in `trunk.md` (fresh branch off `origin/$TRUNK`, `git cherry-pick` the missing commits oldest-first, open a new PR — never force-push the stranded branch itself). Never offer it for deletion.

**Squash-merge fallback (branches NOT `[gone]`).** `[gone]` only fires when the remote deletes the source branch on merge. A branch squash-merged with "delete branch on merge" OFF keeps a live remote and never flips to `[gone]`, so the check above skips it. Do NOT rely on `git branch --merged` or `git cherry` to catch these — squash collapses N commits into one new patch-id, so both report the branch as fully unmerged. Use the same tree-level check as above:

```bash
# (a) branch tip content already fully in the trunk (nothing the branch adds is missing):
git diff "origin/$TRUNK"..<branch> --quiet && echo MERGED   # empty diff → merged
# (b) or the branch's squash commit is present in the trunk's history (match by ticket id):
git log "origin/$TRUNK" --oneline --grep='STU-XXX' | head    # non-empty → merged
```

(a) can read DIFF when the trunk has simply moved *ahead* of the merge — later commits re-touching the same files. In that case (b) is authoritative: if the squash commit is in `origin/$TRUNK`, the branch is merged regardless of drift. Present these under the same preview group (label them "merged, remote not deleted") so the single confirmation covers them too.

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

NOT on the trunk — recovery needed (never deletable):
  stu-1210-refresh-token-fix   2 commits missing from origin/main
    Recovery: cherry-pick onto origin/main on a fresh branch, open a new PR.
    See plugins/toolbox/skills/start-issue/trunk.md — do not force-push this branch.

Skipped (dirty — left untouched):
  .worktrees/feature-export  (3 uncommitted files)

Proceed? [y/N]
```

The "NOT on the trunk" group (and any other never-deletable group) is informational — it sits outside the y/N, since there's nothing to confirm deleting. Use **AskUserQuestion** or a plain yes/no for the deletable groups. One confirmation for the whole deletable batch. If the user says no, stop — change nothing.

### 4. Execute (only after approval)

**Never execute against a never-deletable group** — "not on the trunk — recovery" and any group added by later steps of this procedure. Those are shown so the operator can act on them separately (cherry-pick, new PR); they are never part of what the y/N confirms.

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

**After pruning dangling records, re-scan for orphaned branches.** `git worktree prune` removes the *worktree record* but never touches the branch it pointed at — that branch is now worktree-less and, if `[gone]`/merged, still needs its own `git branch -D`. Re-run the `[gone]` + squash-merge detection over remaining branches once pruning is done, and sweep any merged branch with no worktree:

```bash
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/   # any leftover [gone]?
```

### 5. Report

Print what was removed and what was skipped (and why). Re-run `git worktree list` **and** `git for-each-ref refs/heads/` to confirm — the first alone hides orphaned branches left by a pruned worktree.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Using `git branch --merged <base>` to find merged branches | Squash-merge defeats it. Use `[gone]` upstream after `git fetch --prune`. |
| `git branch -d` then giving up on "not fully merged" | Use `-D` — the preview/confirm is the safety, not git's merge check. |
| Treating every `[gone]` branch as "merged to the trunk" | `[gone]` fires on a merge into ANY base, including a dead intermediate branch (stacked PRs). Gate on `git merge-base --is-ancestor <branch> "origin/$TRUNK"` first. |
| Force-deleting a `[gone]` branch that fails `--is-ancestor` without checking the tree diff | That check alone doesn't distinguish squash-merged (safe) from stranded (not). Disambiguate with `git diff "origin/$TRUNK"..<branch> --quiet` before deciding. |
| Skipping `git fetch --prune` | Without it upstreams never flip to `[gone]` and nothing is detected. |
| `git worktree remove --force` on dirty trees | Never. Exclude dirty worktrees and warn; the user decides manually. |
| Deleting `gitbutler/workspace` or `backup/*` you didn't list | Hard guards. `gitbutler/*` is internal; only delete `backup/*` when shown in preview. |
| Removing the current worktree / main checkout | Always exclude `git rev-parse --show-toplevel` and the first `git worktree list` entry. |
| Confirming "clean" with `git worktree list` only | It hides branches orphaned by a pruned worktree. Also check `git for-each-ref refs/heads/` and sweep leftover `[gone]` branches. |
| A stale worktree lock (dead session pid) blocks `remove` | `git worktree unlock <path>` first, then `remove`. Verify the pid is dead (`kill -0 <pid>`) before overriding a lock. |

## Notes

- A `[gone]` upstream means *the source branch was deleted on some merge* — not necessarily a merge into the trunk (see the stacked-PR gate above), and in rare cases not a merge at all. The preview (branch name + last commit, or the recovery group) is the human check; that's why this skill never runs fully unattended.
- Works from any repo — a generic git worktree cleaner for the squash-merge + `.worktrees/<branch>` workflow. If your remote doesn't delete source branches on merge, `[gone]` never appears and nothing is detected — enable "delete branch on merge" (or delete the remote branch yourself) for this to work.