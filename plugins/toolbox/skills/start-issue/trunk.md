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
git -C "$WT" branch -r --contains "$(git -C "$WT" rev-parse HEAD)" | grep -q "origin/$TRUNK"
```

The fetch is not optional — a local `origin/main` two commits stale answers for a trunk
that no longer exists.

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
   Recovery: cherry-pick onto origin/main on a fresh branch, open a new PR.
   Do not force-push <branch> — its PR is merged and closed.
```

Passing is one line, or silence in a report that has no other failures.
