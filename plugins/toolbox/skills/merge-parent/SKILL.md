---
name: merge-parent
description: Use when asked to merge the parent/base branch into the current branch, sync a feature branch with develop/main, or update a branch before review. Validates the active worktree and branch before touching anything, and runs an anti-drop check on every conflict resolution.
---

# merge-parent

## Overview

Fetches the latest parent branch and merges it into the current branch. Validates context first (right branch, right worktree), and — the core value of this skill — runs a **mechanical anti-drop check** on every conflict resolution before it's committed, so a "trivial-looking" conflict resolution can never silently revert already-merged work from the parent.

**Core insight:** conflict resolution that picks one side wholesale (`-X ours`/`-X theirs`, "keep the develop version", eyeballing a diff and judging it trivial) is exactly how shipped code gets silently reverted. There's no revert commit, no flag in history — `git log -S '<code>'` won't even catch it. The fix isn't "be more careful," it's a mechanical diff-against-both-sides check that can't be skipped by confidence.

## Step 1 — Identify the active worktree

The shell doesn't change directory between calls — always prefix git commands with the worktree's absolute path.

```bash
git worktree list
```

If the user names a worktree/branch, match it to find the absolute path. **If none is named**, use the current directory:

```bash
WORKTREE=$(git rev-parse --show-toplevel)
BRANCH=$(git -C "$WORKTREE" branch --show-current)
```

## Step 2 — Determine the parent branch

Don't hardcode `develop`. Resolve it the same way as this repo's own convention, in order:

```bash
# 1. Remote's configured default branch
PARENT=$(git -C "$WORKTREE" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@')
# 2. Fall back to whichever of these exists on the remote
[ -z "$PARENT" ] && for cand in develop main master; do
  git -C "$WORKTREE" show-ref --verify -q "refs/remotes/origin/$cand" && { PARENT="$cand"; break; }
done
```

If the user explicitly names a parent branch ("merge main into this"), that overrides detection.

## Step 3 — Validate we're on a feature branch

```bash
BRANCH=$(git -C "$WORKTREE" branch --show-current)
```

**Stop if the branch is:**
- the parent branch itself (merging a branch into itself is a no-op / mistake)
- empty (detached HEAD)

Show the plan before doing anything:
```
Worktree : /path/to/.worktrees/feature-x
Branch   : feature/bulk-task-activities
Action   : merge origin/develop → this branch
```

## Step 4 — Fetch and merge

```bash
git -C "$WORKTREE" fetch origin "$PARENT"
git -C "$WORKTREE" merge "origin/$PARENT" --no-edit
```

**Clean merge (fast-forward or no conflicts):**
```
✅ Merge succeeded — no conflicts
```
Push immediately:
```bash
git -C "$WORKTREE" push origin "$BRANCH"
```

**Conflict:**
```
⚠️  Conflict in: src/hooks/useSomething.ts
```

## Step 5 — Resolve conflicts

> ⚠️ **Hard rule: merging the parent must never delete code that exists on the parent, unless the current branch deliberately removed it.** Resolving a conflict by "keeping one side" is the single most common way shipped work vanishes without a trace.

```bash
git -C "$WORKTREE" diff --diff-filter=U --name-only
```

For **each** conflicted file, capture all three versions **before touching anything** (the staged blobs disappear on `git add`):

```bash
# :1 = common ancestor (base), :2 = our branch (ours), :3 = parent (theirs)
git -C "$WORKTREE" show :1:"$file" > /tmp/merge-base.txt
git -C "$WORKTREE" show :2:"$file" > /tmp/merge-ours.txt
git -C "$WORKTREE" show :3:"$file" > /tmp/merge-theirs.txt
```

Then resolve:
1. Read the file with conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
2. Combine both sides where possible (independent additions) — don't pick a whole-side winner
3. Use an edit tool to replace the markers with the resolved version
4. **Don't `git add` yet** — go to Step 6 first

## Step 6 — Mechanical anti-drop verification

**Mandatory for every resolved file, before `git add`.** Don't rely on "this conflict looks trivial" — that judgment is exactly what lets a silent drop through.

Diff the resolution against both sides:

```bash
# Lines present on the parent (theirs) but ABSENT from the resolution:
diff /tmp/merge-theirs.txt "$WORKTREE/$file"   # '<' prefix = lost vs. parent
# Lines present on our branch (ours) but ABSENT from the resolution:
diff /tmp/merge-ours.txt "$WORKTREE/$file"     # '<' prefix = lost vs. our branch
```

For **every `<` line lost vs. the parent**, apply this invariant:

- Did **our branch** deliberately remove/replace that line? Check:
  ```bash
  diff /tmp/merge-base.txt /tmp/merge-ours.txt
  ```
  - **Yes, our branch changed it** → intentional drop, fine.
  - **No, our branch never touched that area** → 🚨 **silent drop** — this is reverting parent work. **Stop immediately, do not commit.**

For **every `<` line lost vs. our branch** that is a guard — a typed `except`,
an early return, a validation, an error handler — the line diff is not enough.
The parent may have **moved the responsibility** rather than dropped it: the work
your guard protected now runs on another thread, inside another function, behind
another handler. "The parent changed this area" then reads as intentional and the
check passes clean, while the behaviour is gone.

Ask where that responsibility lives in the parent's new structure, and re-place
the guard there. Watch for a catch-all (`except Exception`, `catch (e)`) that now
sits between the work and your typed handler — it swallows the exception your
branch added, and no line was lost to show it.

Present a per-file summary **before any commit**:

```
Conflict resolved: src/components/Foo.tsx

  Lost vs. parent (4 lines):
    - const { dictionary } = useSomething();
    - location: resource && !resource.isPlaceholder ? resource.name : undefined,
    ...
  → our branch did NOT touch this area  🚨 likely silent revert

  Lost vs. our branch: none

Keep the parent version, ours, or both? (waiting for your answer before committing)
```

If the check is **clean** (no unexplained drop on either side), still show the per-file resolution diff and ask for an explicit go-ahead before committing:

```
Conflict resolved: src/hooks/useSomething.ts
  ✅ No line lost from the parent
  ✅ No line lost from our branch
  (independent additions on both sides, merged)

OK to commit + push?
```

Once approved and every file is verified:

```bash
git -C "$WORKTREE" add <resolved files>
git -C "$WORKTREE" commit --no-edit
git -C "$WORKTREE" push origin "$BRANCH"
```

## Final summary

```
Merge origin/develop → feature/bulk-task-activities

  ✅ Fetch origin/develop
  ✅ Clean merge (or: resolved 1 conflict in useSomething.ts)
  ✅ Anti-drop check: no line lost from parent
  ✅ Push origin/feature/bulk-task-activities

Commit: abc1234 "Merge remote-tracking branch 'origin/develop' into ..."
```

## Common mistakes

| Situation | Action |
|-----------|--------|
| Branch = parent branch itself | Stop — merging a branch into itself is a no-op |
| Detached HEAD | Stop — ask the user to check out a branch |
| Line lost from parent, untouched by our branch | 🚨 Stop — likely silent revert, show the summary, wait for a decision |
| Logical conflict (not just independent additions) | Stop — show both versions, wait for a decision |
| Clean conflict (independent additions) | Verify (Step 6), show the diff, wait for explicit go-ahead before commit+push |
| Push rejected (remote ahead) | `git -C "$WORKTREE" pull --rebase origin "$BRANCH"` then re-push |
