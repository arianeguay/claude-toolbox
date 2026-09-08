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

**PR lookup, once (if a host CLI is available).** Both gates below need to know, per branch, whether it has a merged PR and — critically — what commit that PR actually merged, which can differ from the branch's current tip (see the tip check at the end of this step). Ask the host once for the whole repo rather than per branch:

```bash
REMOTE=$(git remote get-url origin 2>/dev/null)
case "$REMOTE" in
  *gitlab*) CLI=glab ;;
  *github*) CLI=gh   ;;
  *)        CLI=      ;;
esac

gh pr list --state all --limit 1000 --json number,state,headRefName,mergedAt,headRefOid
```

Match by `headRefName`. A branch with a `MERGED` PR gets a `headRefOid` from this — use it, not the branch's live tip, for the gates below. No host CLI, or no matching PR → there's no `headRefOid`; the gates fall back to the branch's own tip, with the caveat noted at each step.

**`[gone]` is not "merged to the trunk".** GitHub/GitLab delete the source branch on ANY merge — including a merge into a now-dead intermediate base branch (a stacked-PR shape: branch B merges into branch A, and A is itself already merged, or never merges at all). Treating `[gone]` alone as "merged" force-deletes the last copy of a stranded branch. Gate every `[gone]` branch on the trunk before calling it a candidate, reusing the check `plugins/toolbox/skills/start-issue/trunk.md` already owns ("Did the work reach the trunk?" — a merge is a claim about the trunk's history, and only the trunk's history answers it). Run it against `headRefOid` from the PR lookup when one was found, **not** the branch's live tip — a branch with a trailing post-merge commit (see the tip check below) has a tip that was never in any PR, and checking that tip directly would read the trailing commit as part of the merge and misclassify "merged, plus one unlanded commit" as fully stranded:

```bash
REF="${HEAD_REF_OID:-<branch>}"     # headRefOid from the PR lookup above, else the branch's own tip
git merge-base --is-ancestor "$REF" "origin/$TRUNK" && echo REACHED || echo NOT_ANCESTOR
```

- `REACHED` → the trunk has this content. **Merged candidate** — still subject to the tip check below.
- `NOT_ANCESTOR` → not yet a verdict. A **squash**-merged branch also fails this check — the squash commit on the trunk has a new SHA, so the original commits are never its ancestors. Disambiguate with the tree-level check, same `$REF`:
  ```bash
  git diff "origin/$TRUNK".."$REF" --quiet && echo SQUASH_MERGED || echo STRANDED
  ```
  - empty diff (`SQUASH_MERGED`) → nothing this content adds is missing from the trunk. **Merged candidate** — still subject to the tip check below.
  - non-empty diff (`STRANDED`) → **not a candidate.** The trunk is genuinely missing this content, and nothing will ever pull it forward — if it had a PR, that PR is merged and closed into a dead branch. List it under its own **"not on the trunk — recovery"** group instead of the deletable set:
    ```bash
    git log --oneline "origin/$TRUNK..$REF"    # the commits the trunk is missing
    ```
    Point at the cherry-pick recovery in `trunk.md` (fresh branch off `origin/$TRUNK`, `git cherry-pick` the missing commits oldest-first, open a new PR — never force-push the stranded branch itself). Never offer it for deletion.

**Branches without `[gone]` — ask the host, don't grep commit messages.** `[gone]` only fires when the remote deletes the source branch on merge. A branch squash-merged with "delete branch on merge" OFF keeps a live remote and never flips to `[gone]`, so the check above skips it — and if the remote *never* deletes source branches, `[gone]` finds nothing at all even though every branch is merged. Do NOT rely on `git branch --merged` or `git cherry` here either — squash collapses N commits into one new patch-id, so both report the branch as fully unmerged.

Match each non-`[gone]` local branch to `headRefName` in the PR lookup above:

- `state == MERGED` → run it through the **same gate as the `[gone]` route**, above, using its `headRefOid`. Reuse the gate — finding the branch a different way doesn't excuse skipping it.
- `state == CLOSED` (never merged), or no matching PR at all → **not a candidate.** List it in its own **"no merged PR found"** group; never offer it for deletion.

**No host CLI available — last resort only.** Without `gh`/`glab` there is no `headRefOid` and no direct PR-state signal, so fall back to the tree-level check against the branch's own tip. State its weakness where it's used, not only in this skill's Notes: once the trunk has moved ahead at all, `git diff "origin/$TRUNK"..<branch> --quiet` reads DIFF (non-empty) for basically every branch — on its own it answers "did anything change since", not "was this merged". It also can't distinguish a stranded branch from a merged one with a trailing commit — both read DIFF — so a branch caught here reads as `STRANDED` under this section's gate above, with no sharper "commits after the merge" framing available.

```bash
git diff "origin/$TRUNK"..<branch> --quiet && echo MERGED_UNVERIFIED || echo UNKNOWN
```

- empty diff → a **weak** merged candidate. Label it "merged, remote not deleted (unverified — no host CLI)" in the preview so the operator knows this wasn't confirmed against a PR.
- non-empty diff → **do not assume unmerged, and do not drop it silently.** List the branch in a **"could not classify (no host CLI)"** group instead. An empty preview here reads as "nothing to clean" when the truth is "the tool couldn't tell" — that gap is the failure this replaces.

**Tip check — commits after the merge.** Only runs when the PR lookup found a `headRefOid` for the branch. A branch can receive commits AFTER its PR merges — the gate above still reads `REACHED`/`SQUASH_MERGED` (it ran against `headRefOid`, not the tip, precisely so this stays true), but the trailing commits themselves were never in any PR, and with "delete branch on merge" on, the remote is already gone by the time they're pushed — the local branch is their last copy. Compare the branch's current tip to `headRefOid`:

```bash
git rev-parse <branch>   # or origin/<branch> if the remote copy is still live
```

- tip == `headRefOid` → nothing trailing. Stays a **merged candidate**.
- tip != `headRefOid` → **not a candidate under the "merged" label**, even though the gate above passed. List it in a new **"commits after the merge"** group instead:
  ```bash
  git log --oneline "<headRefOid>..<branch>"     # the trailing commits
  ```
  Worth doing before showing the group: diff each trailing commit's added lines against the trunk's current copy of the same file — a line that already landed via a different PR (reworded but present) isn't a real loss; a line that never landed anywhere is:
  ```bash
  git diff "<headRefOid>..<branch>" --unified=0 -- <file> | grep '^+[^+]'   # lines the trailing commit(s) add
  git show "origin/$TRUNK:<file>"                                          # already there? not a real loss
  ```
  Say the fix is a new PR for the trailing commits — never offer the branch for deletion in the same batch the operator confirms with one keystroke.

No `headRefOid` available (no host CLI, or no PR found for this branch) → this check can't run, and the gate above already used the branch's own tip — see the caveat in the no-host-CLI fallback just above.

### 3. Present the preview, then ask ONCE

Show grouped lists with the last commit subject per branch so the user can sanity-check. Example shape:

```
Worktrees to remove (merged, remote gone):
  .worktrees/feature-login-rework  feature-login-rework  "test(auth): cover token refresh edge cases…"
Branches to delete (merged, no worktree):
  stu-1091-cache-warm-job  "fix(cache): warm on boot…"  (PR #301, remote not deleted)
backup/* branches to delete:
  backup/feature-search-20260601-163329  "fix(search): debounce query input…"
Dangling worktree records to prune:
  (none)

NOT on the trunk — recovery needed (never deletable):
  stu-1210-refresh-token-fix   2 commits missing from origin/main
    Recovery: cherry-pick onto origin/main on a fresh branch, open a new PR.
    See plugins/toolbox/skills/start-issue/trunk.md — do not force-push this branch.

Commits after the merge (never deletable):
  stu-1100-measure-review-distance   1 commit after PR #327 merged — open a new PR for it

No merged PR found (never deletable):
  stu-1188-abandoned-spike   no PR, or PR was closed without merging

Could not classify — no host CLI (never deletable):
  stu-1099-old-experiment   tree diff is not a merged/unmerged signal once main has moved

Skipped (dirty — left untouched):
  .worktrees/feature-export  (3 uncommitted files)

Proceed? [y/N]
```

The "NOT on the trunk" group (and any other never-deletable group) is informational — it sits outside the y/N, since there's nothing to confirm deleting. Use **AskUserQuestion** or a plain yes/no for the deletable groups. One confirmation for the whole deletable batch. If the user says no, stop — change nothing.

### 4. Execute (only after approval)

**Never execute against a never-deletable group** — "not on the trunk — recovery", "commits after the merge", "no merged PR found", "could not classify", and any group added by later steps of this procedure. Those are shown so the operator can act on them separately (cherry-pick, new PR, manual check); they are never part of what the y/N confirms.

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
| Deleting a merged branch without checking its tip against the PR's `headRefOid` | A branch can gain commits after its own PR merges. Compare `git rev-parse <branch>` to `gh pr list --json headRefOid` (matched by `headRefName`) before deleting — trailing commits are the last copy once the remote is gone. |
| Matching a ticket id against trunk commit messages (`git log --grep`) to find merged branches | Matches any commit whose body mentions the ticket, not just the one that landed it — wrong, not just weak, in a repo whose commits cross-reference other tickets. Ask the host (`gh pr list --state all`) instead. |
| Reading `git diff "origin/$TRUNK"..<branch>` as DIFF = "not merged" | It reads DIFF for nearly every branch once the trunk has simply moved ahead. It's a "did anything change" signal, not a merged/unmerged one — use it only when no host CLI exists, and say so in the preview. |
| An empty "merged" preview under a remote that doesn't delete branches on merge | Reads as "nothing to clean" when it may mean "`[gone]` never fires here." Sweep with `gh pr list --state all` before concluding there's nothing to do. |
| Skipping `git fetch --prune` | Without it upstreams never flip to `[gone]` and nothing is detected. |
| `git worktree remove --force` on dirty trees | Never. Exclude dirty worktrees and warn; the user decides manually. |
| Deleting `gitbutler/workspace` or `backup/*` you didn't list | Hard guards. `gitbutler/*` is internal; only delete `backup/*` when shown in preview. |
| Removing the current worktree / main checkout | Always exclude `git rev-parse --show-toplevel` and the first `git worktree list` entry. |
| Confirming "clean" with `git worktree list` only | It hides branches orphaned by a pruned worktree. Also check `git for-each-ref refs/heads/` and sweep leftover `[gone]` branches. |
| A stale worktree lock (dead session pid) blocks `remove` | `git worktree unlock <path>` first, then `remove`. Verify the pid is dead (`kill -0 <pid>`) before overriding a lock. |

## Notes

- A `[gone]` upstream means *the source branch was deleted on some merge* — not necessarily a merge into the trunk (see the stacked-PR gate above), and in rare cases not a merge at all. The preview (branch name + last commit, or the recovery group) is the human check; that's why this skill never runs fully unattended.
- Works from any repo — a generic git worktree cleaner for the squash-merge + `.worktrees/<branch>` workflow. If your remote doesn't delete source branches on merge, `[gone]` never appears — that's expected, not a dead end: the `gh pr list --state all` sweep for non-`[gone]` branches is what finds those. It needs a host CLI; without one, the tree-diff fallback is weak and unclassifiable branches are reported rather than silently dropped.