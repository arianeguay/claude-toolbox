---
name: gitlab-mr-suggestions
description: Use when posting inline comments or one-click code-suggestions on a GitLab merge request diff, or when inline MR comments land as general notes / "aren't tagged to the lines" instead of attaching to the diff.
---

# Posting GitLab MR inline suggestions & notes

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
