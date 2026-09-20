---
name: use-git-worktree
description: Create and address a git worktree for a task, at the one path every tool here agrees on. Use before touching a file for any non-trivial change, when starting work on a branch, or when a skill says to isolate work from the main checkout. Triggers - "make a worktree", "work on a branch", "isolate this", "start this in a worktree". Do NOT use for a trivial edit the user explicitly asked for on the trunk.
user-invocable: true
---

# Use a git worktree

Every task runs in its own worktree. The main checkout stays on the trunk branch and is
never branch-switched, so a second session, a running server or a half-finished edit in
the trunk is never disturbed by this task.

The only exception is a trivial edit the user explicitly asked for on the trunk itself.

## Where worktrees go

```
<repo>/.worktrees/<branch>
```

One path, every repo, every machine. Not `.claude/worktrees/`, not a sibling directory,
not `/tmp`.

This is enforced rather than remembered: `hooks/enforce-worktree-path.sh` runs at
`SessionStart` and after every `Bash` call, creates `<repo>/.worktrees/`, adds
`/.worktrees/` to `.git/info/exclude`, and turns a legacy `<repo>/.claude/worktrees` into
a symlink pointing at it. So a tool that still writes the old path lands in the right
place anyway.

Two things the hook deliberately does not do. It never touches a `.claude/worktrees`
directory that holds real worktrees, because relocating one means repairing the absolute
paths in `.git/worktrees/*/gitdir` and can strand uncommitted work. And it writes to
`.git/info/exclude` rather than `.gitignore`, so no repo carries a diff for it; the cost
is that a fresh clone is uncovered until the hook has run once.

## Creating it

Get the branch name **from the tracker** when there is one. Trackers own this: a
hand-rolled name breaks their branch to issue linking.

- **The tracker only names the branch** (Linear): create it locally.
  ```bash
  git worktree add -b <branch> .worktrees/<branch> origin/<default-branch>
  ```
- **The tracker creates the branch server-side** (GitHub `gh issue develop`, GitLab's
  branch API): it already exists on the remote and carries the link. **Attach** to it.
  Creating a second local branch of the same name silently discards that link.
  ```bash
  git worktree add .worktrees/<branch> <branch>
  ```

A branch name with a slash becomes nested directories under `.worktrees/`. That is fine,
and it is why the exclude entry is `/.worktrees/` rather than a single-level pattern.

## Addressing it

**The worktree holds the files, not the session.** Do not move the session's cwd into it:
no `EnterWorktree`, no `cd`. Sessions are keyed by cwd, so a session that entered a
worktree is filed under that path. `claude --resume` from the main checkout will not list
it, which after a crash is indistinguishable from a session that never existed, and
removing the worktree strands it for good.

Address it explicitly instead, for every read, write and command:

```bash
WT="$(pwd)/.worktrees/<branch>"
git -C "$WT" branch --show-current   # must print <branch>, before the first edit
```

`git -C "$WT"`, `make -C "$WT"`, absolute paths everywhere. A bare `git` command now
lands on the trunk, so the check above is not a formality: run it before the first edit,
and never infer the branch from `pwd`.

## Finishing

Remove the worktree only once the work is merged or abandoned, and never with `rm -rf`
alone, which leaves a dangling administrative record:

```bash
git worktree remove "$WT"        # refuses if the tree is dirty, which is the point
git worktree prune               # only if a directory was already deleted by hand
```

`git worktree remove` refusing is information: something in there is not committed. Read
it before forcing.

## Red flags

| Thought | Reality |
|---------|---------|
| "I'll just switch branches in the main checkout" | That is what this skill exists to prevent. Another session may be mid-edit there. |
| "I'll `cd` into the worktree, it's simpler" | The session gets filed under that path and is lost to `--resume`. Use `git -C`. |
| "`pwd` shows the right branch" | `pwd` is the trunk. Confirm with `git -C "$WT" branch --show-current`. |
| "The hook will move my existing worktree" | It never relocates real worktrees. That is a manual migration. |
| "This change is small, no worktree needed" | Small only excuses the trunk when the user asked for that edit on the trunk. |
