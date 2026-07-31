---
name: git-clean-history
description: Rewrite Git history to make it clean, professional, and senior-level. Use when a user wants to squash messy commits, reorganize history, clean up commit messages, rebase interactively, or prepare a branch for PR/merge. Also use when history contains WIP commits, fixups, debug artifacts, or inconsistent messaging.
---

# Git History Rewrite Skill

Rewrite messy Git history into a clean, professional, senior-developer-quality commit log.

## Safety-First Approach

**Git history rewriting is destructive. Always protect the user.**

1. **Never rewrite shared/pushed history** without explicit user confirmation
2. **Always create a backup branch** before any rewrite operation
3. **Show a dry-run plan** before executing anything
4. **Confirm with user** before force-pushing

### Pre-flight Checklist

Before any rewrite, run these checks:

```bash
# 1. Ensure working tree is clean
git status --porcelain

# 2. Identify the branch and its upstream
git branch --show-current
git rev-parse --abbrev-ref @{upstream} 2>/dev/null

# 3. Detect the base branch: PR/MR target if available, else the remote default
TARGET=$(gh pr view "$(git branch --show-current)" --json baseRefName -q .baseRefName 2>/dev/null) \
  || TARGET=$(glab mr view "$(git branch --show-current)" -F json 2>/dev/null | jq -r '.target_branch // empty') \
  || true
TARGET=${TARGET:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@')}
TARGET=${TARGET:-main}
git fetch -q origin "$TARGET" 2>/dev/null || true
BASE=$(git merge-base HEAD "origin/$TARGET")
[ -n "$BASE" ] || { echo "Cannot resolve base against origin/$TARGET — stop."; exit 1; }

# 4. Check if branch has been pushed (informational only — NEVER the rewrite scope)
git log --oneline @{upstream}..HEAD 2>/dev/null

# 5. Count commits to decide strategy
COMMIT_COUNT=$(git rev-list --count "$BASE"..HEAD)
# If >50 commits, prefer soft reset + recommit over interactive rebase

# 6. Create safety backup
git branch backup/$(git branch --show-current)-$(date +%Y%m%d-%H%M%S)
```

If the working tree is dirty, **stop and ask the user** whether to stash or commit first.

If the branch has been pushed and others may be working on it, **warn the user explicitly** about the risks of rewriting shared history.

**The rewrite scope is always `$BASE..HEAD`** — every commit on this branch since it forked from its base. Never `@{upstream}..HEAD`: that is only the *unpushed* tail, so using it silently skips every commit already pushed and makes the audit look clean on a branch that isn't. Step 4 above prints it for the shared-history warning and nothing else. If `$BASE` failed to resolve, stop — do not fall back to another range.

## Process

### Step 1: Analyze Current History

```bash
# Get the full picture
git log --oneline --graph --all -30

# Show the commits to rewrite (BASE was set in pre-flight)
git log --oneline $BASE..HEAD

# Analyze commit quality
git log --format="%h %s" $BASE..HEAD
```

Classify each commit into one of these categories:

| Category | Description | Action |
|----------|-------------|--------|
| ✅ **Clean** | Atomic, well-messaged, logical | Keep as-is or minor message edit |
| 🔀 **Squash target** | WIP, fixup, "oops", typo fix | Squash into parent logical commit |
| 🧹 **Noise** | Debug logs, console.log, temp files | Drop or squash |
| 📦 **Oversized** | Too many unrelated changes | Split into atomic commits |
| 🔄 **Revert chain** | Revert + re-apply cycles | Collapse to final state |
| 💬 **Bad message** | Vague or non-conventional message | Reword only |

### Step 2: Plan the Rewrite

Present a clear plan to the user in this format:

```
Current history (oldest → newest):
  a1b2c3d feat: add user auth
  e4f5g6h WIP saving progress
  i7j8k9l fix typo
  m0n1o2p add tests maybe?
  q3r4s5t console.log everywhere
  u6v7w8x actually fix the auth bug
  y9z0a1b remove console.logs
  c2d3e4f final cleanup

Proposed rewrite:
  1. feat(auth): add user authentication          ← squash a1b, e4f, i7j
  2. fix(auth): resolve token validation error     ← squash u6v, y9z, c2d
  3. test(auth): add authentication test suite     ← reword m0n
     (drop q3r - debug noise only)
```

### Step 3: Execute the Rewrite

Use the most appropriate Git tool for the job:

#### Non-Interactive Rebase (most common)

Claude Code cannot use interactive flags (`-i`, `-p`), so script the rebase using `GIT_SEQUENCE_EDITOR`:

```bash
# Build the rebase todo commands in a script file
cat > /tmp/rebase-todo.sh << 'SCRIPT'
#!/bin/bash
# Modify the todo file: change pick to squash/drop/reword as needed
sed -i '' 's/^pick e4f5g6h/squash e4f5g6h/' "$1"
sed -i '' 's/^pick i7j8k9l/squash i7j8k9l/' "$1"
sed -i '' 's/^pick q3r4s5t/drop q3r4s5t/' "$1"
sed -i '' 's/^pick y9z0a1b/squash y9z0a1b/' "$1"
sed -i '' 's/^pick c2d3e4f/squash c2d3e4f/' "$1"
SCRIPT
chmod +x /tmp/rebase-todo.sh

# Run rebase non-interactively
GIT_SEQUENCE_EDITOR="/tmp/rebase-todo.sh" git rebase -i $BASE
```

The plan determines the sed commands. For example, given:

```
Current plan:
  1. feat(auth): add user authentication          ← squash a1b, e4f, i7j
  2. fix(auth): resolve token validation error     ← squash u6v, y9z, c2d
  3. test(auth): add authentication test suite     ← reword m0n
     (drop q3r - debug noise only)
```

#### Soft Reset + Recommit (for complete overhaul)

When history is too messy for rebase, or when the branch has **>50 commits** (rebase becomes unwieldy at that scale). This is often the simplest approach in Claude Code since it avoids rebase complexity:

```bash
# Reset to merge base, keeping all changes staged
git reset --soft $BASE

# Now recommit in logical, atomic chunks
git reset HEAD  # unstage everything

# Stage specific files/directories and commit each logical chunk
git add src/features/auth/
git commit -m "feat(auth): add user authentication"

git add src/features/auth/__tests__/
git commit -m "test(auth): add authentication test suite"
```

Stage by file path or glob pattern — never use `git add -p` (interactive, unsupported in Claude Code).

#### Autosquash (when fixup commits are marked)

```bash
# If commits use fixup!/squash! prefixes — use GIT_SEQUENCE_EDITOR to skip interactive editor
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $BASE
```

### Step 4: Validate the Rewrite

After rewriting, verify everything is correct:

```bash
# 1. Compare the tree - MUST be identical to before rewrite
git diff backup/<branch-name>-<timestamp> HEAD
# This should produce NO output. If it does, something went wrong.

# 2. Verify commit count is reasonable
git log --oneline $BASE..HEAD

# 3. Check all commit messages follow convention
git log --format="%h %s" $BASE..HEAD

# 4. Verify no unintended file changes
git diff --stat backup/<branch-name>-<timestamp> HEAD
```

**Critical: The diff between the backup branch and the rewritten branch MUST be empty.** History rewriting should only change commits, never the final code state.

### Step 5: Clean Up

```bash
# If user confirms everything looks good
git branch -D backup/<branch-name>-<timestamp>

# If user needs to push (with explicit confirmation)
git push --force-with-lease origin <branch-name>
```

Always use `--force-with-lease` instead of `--force` to prevent overwriting others' work.

## Commit Message Quality Standards

When rewriting commit messages, follow these senior-level standards:

### Do ✅

- Use Conventional Commits format: `type(scope): description`
- Check CLAUDE.md or recent `git log` for project-specific scopes and conventions
- Use imperative mood: "add", "fix", "refactor" (not "added", "fixes")
- Keep subject line under 72 characters
- Make each commit atomic: one logical change per commit
- Add body for non-obvious "why" context
- Reference ticket/issue numbers when available

### Don't ❌

- `"fix stuff"`, `"WIP"`, `"asdf"`, `"please work"`
- `"fix bug"` without specifying which bug
- `"update file.ts"` — describe the change, not the file
- Commits that mix unrelated changes (formatting + feature + bugfix)
- Empty or auto-generated messages
- Overly long subject lines that wrap

### Ideal Commit Structure for a Feature Branch

A clean branch should tell a story:

```
feat(booking): add slot conflict detection            ← core feature
feat(booking): add UI feedback for time conflicts      ← UI layer
test(booking): add conflict detection unit tests       ← tests
docs(booking): update API docs for conflict endpoint   ← docs
```

Each commit should:
- Be independently reviewable
- Pass CI on its own (if possible)
- Have a clear, single purpose
- Build logically on the previous commit

## Common Scenarios

### Scenario: "I have dozens of WIP commits on my feature branch"

Default to soft reset + recommit — it's the simplest approach in Claude Code:

```bash
git reset --soft $BASE
# Then carefully restage by file path and recommit in logical chunks
```

For **<10 commits**, scripted rebase via `GIT_SEQUENCE_EDITOR` is also clean. For **>10**, soft reset is almost always simpler.

### Scenario: "I need to split one big commit into several"

```bash
# Script the rebase to mark the commit as "edit"
GIT_SEQUENCE_EDITOR="sed -i '' 's/^pick <short-hash>/edit <short-hash>/'" git rebase -i <commit>^

# Undo the commit, keep changes
git reset HEAD^

# Stage first logical chunk by file path
git add src/features/x/core.ts src/features/x/utils.ts
git commit -m "feat(x): first part"

# Stage second chunk
git add src/features/x/ui/ src/features/x/__tests__/
git commit -m "feat(x): second part"

git rebase --continue
```

### Scenario: "I want to reorder commits"

```bash
# Script the rebase to reorder lines in the todo list
cat > /tmp/reorder-todo.sh << 'SCRIPT'
#!/bin/bash
# Move commit c3d after a1b by rewriting the todo file
# Adjust the sed commands to match the actual commit order needed
SCRIPT
chmod +x /tmp/reorder-todo.sh

GIT_SEQUENCE_EDITOR="/tmp/reorder-todo.sh" git rebase -i $BASE
# Be aware of dependency order — commits that depend on earlier ones can't be moved before them
```

### Scenario: "Merge conflicts during rebase"

```bash
# During rebase, if conflicts occur:
git status                          # see conflicted files
# Resolve conflicts in each file
git add <resolved-files>
git rebase --continue

# If it's too messy, abort and rethink strategy:
git rebase --abort
```

## Output

When presenting results to the user:

1. **Show the before/after comparison** of the commit log
2. **Confirm the diff is empty** (code state unchanged)
3. **Display the final clean history** with commit hashes
4. **Remind about force-push** if the branch was already pushed
5. **Offer to delete the backup branch** once confirmed

## Edge Cases & Warnings

- **Signed commits**: Rewriting history invalidates GPG signatures
- **CI references**: If CI references specific commit SHAs, those will break
- **Merge commits**: Consider `--rebase-merges` to preserve merge topology when needed
- **Stacked branches**: Use `git rebase -i --update-refs` (Git 2.38+) to automatically update dependent branch pointers during rebase. Without this, child branches will point to orphaned commits.
- **Submodules**: Extra care needed — submodule pointers can break during rebase
- **Large binary files**: Consider if LFS migration is needed during the cleanup
- **Secrets in history**: Out of scope for this skill. Use `git-filter-repo` or BFG Repo Cleaner for scrubbing secrets from history — those are fundamentally different (and heavier) operations. Always rotate credentials immediately after removal.
