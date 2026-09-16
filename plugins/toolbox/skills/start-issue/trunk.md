# Did the work reach the trunk?

Shared by `start-issue` (Steps 2 and 8), `start-milestone` (Step 4) and `mr-ship`
(Step 11). One definition, because a check restated in three files drifts in three
directions.

**Principle:** a merge is a claim about the trunk's history, so only the trunk's history
answers it. Every other signal — the PR state, the tracker state, the branch being gone —
is a claim about the *PR*, and a PR can be merged into something that is not the trunk.

## The check

```bash
TRUNK=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)
git -C "$WT" fetch -q origin
git -C "$WT" merge-base --is-ancestor HEAD "origin/$TRUNK"    # exit 0 = the trunk has it
```

The fetch is not optional — a local `origin/main` two commits stale answers for a trunk
that no longer exists.

**A squash merge fails this check, correctly and uselessly.** Squashing writes a *new*
commit, so the branch's commits are never ancestors of the trunk and `--is-ancestor` exits
non-zero on work that landed perfectly. It fails closed, which is the safe direction, but a
flow that stops on it will hunt a phantom drop and may "recover" by cherry-picking work the
trunk already has. When the merge was a squash — or when you do not know which it was —
ask about **content**, not ancestry:

```bash
git -C "$WT" fetch -q origin
CHANGED=$(git -C "$WT" diff --name-only "$(git -C "$WT" merge-base "origin/$TRUNK" HEAD)" HEAD)
git -C "$WT" diff --quiet "origin/$TRUNK" HEAD -- $CHANGED    # exit 0 = the trunk has this work
```

Diffing the whole tree against `origin/$TRUNK` fails the same way `--is-ancestor` does: the
trunk moving for a reason that has nothing to do with this branch (a concurrent session's PR
landing during the same window) makes the diff non-empty and reports a drop that never
happened. Scoping the diff to the files the branch actually changed answers "did my change
land" instead of "are these two trees identical". Use `--is-ancestor` for merge and rebase,
the scoped content diff for squash; when in doubt, the content diff answers both. Observed
2026-09-08: `gh pr merge --squash` on a clean PR reported `NOT ON TRUNK` under
`--is-ancestor` while the trunk held all 13 files. Observed 2026-09-11: the unscoped content
diff then reported `NOT ON TRUNK` on two more repos whose PRs had landed cleanly, because an
unrelated PR merged into the same trunk during the same window.

**Ask git, do not grep git's output.** The obvious form —
`git branch -r --contains <sha> | grep -q "origin/$TRUNK"` — matches on substring, so any
sibling ref whose name starts with the trunk's (`origin/main-experiment`, `origin/mainline`,
an upstream fork's `origin/main`) satisfies the grep and the check passes while the trunk
has none of the work. Measured on the repro in this repo's history: with the child pushed to
`main-experiment`, the grep form reports the trunk contains it and `--is-ancestor` fires.
Fails open, in the direction that looks like success — the same defect this file is about.

## What is not evidence

| Signal | What it actually says |
|---|---|
| `gh pr view --json state` → `MERGED` | The PR merged **into its base**. Says nothing about which branch that was. |
| `mergedAt` set | Same. It is a timestamp on the same claim. |
| The tracker in a review/done state | Someone wrote it there, on one of the two signals above. |
| The remote branch `[gone]` | The base's owner deleted it. Also true of a stacked base. |

## The shape that produces a false MERGED

A **stacked PR** — one opened against another PR's branch rather than the trunk, which is
what happens whenever an issue's premise lives in an unmerged PR:

1. The base PR merges to the trunk. Its branch is now a merged dead end.
2. The child PR merges — into that dead end. GitHub does not retarget it.
3. `gh pr view <child>` says `MERGED`. The trunk has none of the work, and nothing will
   ever pull it forward: the child's PR is merged and closed.

## The recovery

Cherry-pick onto the current trunk on a **fresh branch**, and open a **new PR**:

```bash
git -C "$WT" fetch -q origin
git -C "$WT" log --oneline "origin/$TRUNK..HEAD"        # the commits the trunk is missing
git worktree add -b <branch>-onto-trunk <path> "origin/$TRUNK"
git -C <path> cherry-pick <sha>...                      # oldest first
```

**Never force-push the old branch.** Its PR is merged and closed — rewriting the branch
changes nothing about the trunk, cannot reopen the PR, and loses the audit trail of what
was reviewed. A guard that only says "not on the trunk" sends someone to reopen a PR that
cannot be reopened; say the recovery, not just the failure.

## Reporting it

Name the trunk the commits are missing from, and the count:

```
❌ NOT ON TRUNK — 2 commits merged into arianedguay/stu-1210-…, not origin/main
   Files that differ: src/auth.ts, src/auth.test.ts
   Recovery: cherry-pick onto origin/main on a fresh branch, open a new PR.
   Do not force-push <branch> — its PR is merged and closed.
```

Print `git diff --name-only origin/$TRUNK HEAD` alongside every failure of the content-diff
check. When the trunk moved for an unrelated reason, the differing files are someone else's
and that is visible at a glance, without a second command.

Passing is one line, or silence in a report that has no other failures.
