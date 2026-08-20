# Tracker: GitHub Issues (`gh`)

```bash
gh auth status || echo "STOP — gh auth login"
```

URL shape: `https://github.com/<owner>/<repo>/issues/<n>` → the key is `#<n>`.

GitHub has no workflow-state field: an issue is `OPEN` or `CLOSED`. "In Progress" / "In
Review" live in a **Project v2 status field**, or as labels, or nowhere. Detect which the
repo already uses — never invent a third mechanism.

```bash
OWNER=$(gh repo view --json owner -q .owner.login)
gh project list --owner "$OWNER" 2>/dev/null
gh label list --limit 100 | grep -iE 'status|wip|progress|review'
```

## Read (Step 1)

```bash
gh issue view <n> --json number,title,body,state,labels,assignees,milestone,url,projectItems
gh issue view <n> --comments
```

Blocked check: GitHub has no dependency primitive outside Projects v2. Read the body for
`Blocked by #<n>` / `Depends on #<n>` and check each referenced issue's state — an open one
blocks the start.

## Backfill (Step 1)

```bash
gh issue edit <n> \
  --title "<imperative, scoped, no key prefix>" \
  --body-file <(cat <<'BODY'
<markdown body>
BODY
) \
  --add-label bug --add-label "size: M"
```

`--add-label` is additive (unlike Linear's replace-the-set) — use `--remove-label` for the
ones that must go. Labels must already exist; `gh label create` first or fall back to one
the repo has. Estimate/priority: whichever the repo already uses (a `size:`/`priority:`
label, or a Project v2 number field) — say which one you used.

## Branch name (Step 2)

GitHub owns the branch↔issue link through `gh issue develop`. Use it — it creates the
branch **and** registers the link, which a plain `git branch` does not:

```bash
gh issue develop <n> --name "<n>-<kebab-title>" --base "$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
```

That pushes the branch to the remote. Then attach the worktree to it rather than creating a
second branch:

```bash
git fetch origin "<n>-<kebab-title>"
git worktree add .claude/worktrees/<n>-<kebab-title> "<n>-<kebab-title>"
```

`gh issue develop` unavailable (old `gh`, no write scope) → create the branch normally and
say the issue link is body-only.

## State transitions (Steps 3 and 7)

In the repo's existing mechanism, in this order of preference:

```bash
# 1. Project v2 status field (the real one when the repo uses Projects)
gh project item-list <number> --owner "$OWNER" --format json     # find the item id + field ids
gh project item-edit --id <item-id> --project-id <pid> --field-id <fid> --single-select-option-id <oid>

# 2. Status labels, if the repo uses them
gh issue edit <n> --add-label "status: in progress" --remove-label "status: todo"

# 3. Neither exists
gh issue edit <n> --add-assignee "@me"
```

Case 3 is the honest degradation: assignment is the only signal GitHub gives you. Say in
the Step 8 report that the repo carries no workflow state, rather than pretending a
transition happened. Never `gh issue close` as a stand-in for "in review".

## Link the PR back (Step 7)

Put `Closes #<n>` in the PR body — that is GitHub's native issue↔PR link and it auto-closes
on merge. For an issue the PR should *not* close, use `Refs #<n>` and comment the URL:

```bash
gh issue comment <n> --body "PR: <url>"
```
