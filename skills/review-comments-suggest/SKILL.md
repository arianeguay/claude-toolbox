---
name: review-comments-suggest
description: Use when posting inline comments or one-click code-suggestions on a PR/MR diff, or when inline comments land as general notes / "aren't tagged to the lines" instead of attaching to the diff. GitLab tooling included; see the GitHub equivalent section for `gh`. Pairs with `toolbox:review-comments-resolver` (that skill reads/resolves feedback, this one posts it).
user-invocable: true
---

# Posting inline PR/MR suggestions & notes

## Overview

An inline MR comment must carry a nested `position` object. The trap: **`glab api -f "position[new_line]=N"` does not serialize bracket notation** — GitLab silently drops `position` and creates a *general* note (HTTP 201, `position: null`, no error). That's why "comments aren't tagged to the lines." Post the nested JSON directly instead.

Use `scripts/mr_comment.py` (stdlib only; token from `$GITLAB_ACCESS_TOKEN` or `glab`).

## Hard limits on anchoring

- A comment attaches **only to a line present in the unified diff** — a changed line or its ±3 context. A line in a large **unchanged island** (a section that survived a rewrite verbatim) is *not in the diff* → no inline comment possible there. Fall back to a **note on the nearest changed line** pointing at the spot.
- **Added** line → send `new_line` only. **Unchanged context** line → send `new_line` AND `old_line`.
- **Code suggestion** = body contains a fence whose **first line reproduces the anchored line verbatim**, then the replacement/added lines. To *append* after a line: fence = anchor line + your new lines.

````
```suggestion:-0+0
<exact text of the anchored line>
<line(s) you are adding>
```
````

## Workflow

1. **Locate** the target — tells you added vs context vs absent, and the exact flags:
   ```
   scripts/mr_comment.py locate --project owner/repo --mr 1734 --path CLAUDE.md --match "SCSS modules"
   ```
2. **Build the body** in a file. For a suggestion, pull the anchor line verbatim from git so you never mistype it:
   ```
   git show <branch>:<path> | sed -n '147p'
   ```
3. **Post** (added line shown; add `--old-line M` for a context line):
   ```
   scripts/mr_comment.py post --project owner/repo --mr 1734 --path CLAUDE.md --new-line 147 --body-file note.md
   ```
   The script verifies `position != null` and fails loudly if it degraded to a general note.

## Suggestion vs. note — pick by anchor

| Situation | Do |
|---|---|
| Target is an ADDED line (or any new file) | one-click `suggestion` fence |
| Target is a CONTEXT line | suggestion works; pass `--old-line` too |
| Target is in an unchanged island (ABSENT from diff) | plain inline **note** on the nearest added line, quoting what to add |

## Common mistakes

- Trusting the POST's 201 — it returns 201 even when position is dropped. **Verify `position != null`** (the script does).
- Retyping the anchor line in a suggestion — one stray char and the fence won't apply. Copy it from `git show`.
- Trying to suggestion-anchor an unchanged section — impossible; it's not in the diff.
- Using `old_path`/`new_path` wrong on renames — for the common case they're identical.
- **Sent `new_line` ≠ stored `new_line`.** On large/collapsed-diff files, the line you send can resolve to ±1 (raw-diff vs MR-diff numbering). Trust the **stored** `new_line` the script prints, and confirm your fence's first line is the file's content at *that* line. If it 400s, try ±1.

## GitHub equivalent

This skill and its script are GitLab-only. GitHub's inline PR review comment API is **flat**, not nested — the bug this skill works around doesn't exist there, because there's no nested object for `-f`/bracket notation to mangle.

| | GitLab (`glab`/REST v4) | GitHub (`gh`/REST) |
|---|---|---|
| Endpoint | `POST .../merge_requests/:iid/discussions` | `POST .../pulls/:number/comments` |
| Anchor shape | nested `position: {base_sha, start_sha, head_sha, old_line, new_line, ...}` | flat `commit_id`, `path`, `line`, `side` |
| Added line | `new_line` only | `line=<new>`, `side=RIGHT` |
| Old/deleted-side line | not supported by this script | `line=<old>`, `side=LEFT` |
| Context line | both `old_line` + `new_line` together | single `line` + `side` (no dual old/new needed) |
| Multi-line range | not supported by this script | `start_line` + `start_side` alongside `line`/`side` |
| `-f`/bracket-notation trap | **yes** — silently drops `position`, lands as a general note | **no** — flat fields serialize fine with `gh api -f`/`-F` |
| Suggestion fence syntax | ` ```suggestion:-0+0 ` (needs the offset) | ` ```suggestion ` (no offset — GitHub always targets the exact commented line) |
| Verify anchor stuck | check response `position != null` | a bad anchor **422s outright** — no silent degrade to catch |

Example GitHub post (added line):
```bash
gh api repos/OWNER/REPO/pulls/123/comments \
  -f body="$(cat note.md)" \
  -f commit_id="$(gh pr view 123 --json headRefOid -q .headRefOid)" \
  -f path="CLAUDE.md" \
  -F line=147 \
  -f side=RIGHT
```

Same diff-only anchoring limit applies on both platforms — a line absent from the unified diff (an unchanged island) can't be targeted. No wrapper script exists here for GitHub: `gh api -f` doesn't hit the nested-serialization trap, so the flat command above is usually enough on its own.
