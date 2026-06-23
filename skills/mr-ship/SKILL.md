---
name: mr-ship
description: Use when ready to submit a PR/MR for review — runs the full pre-review pipeline in sequence (resolve feedback, mechanical checks, footprint reduction, uniformity, context validation, review, comment audit, clean history, description). Triggers - "ship it", "ready for review", "run the pre-review pipeline".
user-invocable: true
---

# Ship (pre-review pipeline)

One command from "code done" to "ready for review." Runs the toolbox skills in order, fixes what it can, tells you exactly what it can't. Provider-agnostic (GitHub `gh` / GitLab `glab`).

**Ship-only-what's-asked:** the pipeline catches scope creep, over-engineering, and cruft, then cuts it before the reviewer sees it.
**ADHD-friendly:** automate everything possible; when it needs you, say exactly what to do (not what to think about). Aim for ≤5 human actions across the whole run.

Each step **invokes another toolbox skill** — this file is just the orchestration and order. If a step's skill isn't installed, note it and continue.

---

## Step 0 — Setup
```bash
BASE=$(gh pr view "$(git branch --show-current)" --json baseRefName -q .baseRefName 2>/dev/null) \
  || BASE=$(glab mr view "$(git branch --show-current)" -F json 2>/dev/null | jq -r '.target_branch // empty') \
  || true
BASE=${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)}
git fetch -q origin "$BASE" 2>/dev/null || true
BRANCH=$(git branch --show-current)
FILES=$(git diff "origin/$BASE...HEAD" --name-only | wc -l | tr -d ' ')
```
Show: `Ship — {branch} → {BASE} ({FILES} files)`. Detect whether a PR/MR already exists (`gh pr view "$BRANCH"` / `glab mr view "$BRANCH"`).

---

## Pipeline (in order)

| # | Step | Skill | Blocks? |
|---|------|-------|---------|
| 1 | Resolve review feedback (iterations only) | `review-comments-resolver` | only if user dismisses |
| 2 | Mechanical checks | `mechanical-checks` | never (accumulates) |
| 3 | Footprint reduction | `smallest-footprint` | only on risky findings |
| 4 | Uniformity check | `uniformity-check` | only on discussable findings |
| 5 | Context validation | `context-validator` | only if user reports an issue |
| 6 | Deep code review | *(see Step 6)* | never (accumulates) |
| 7 | Comment audit | `comment-audit` | only if user dismisses |
| 8 | Clean history | `git-clean-history` | never (presents options) |
| 9 | PR/MR description | `mr-description` | runs automatically |

### Step 1 — Resolve review feedback (iterations only)
If a PR/MR already exists, invoke `review-comments-resolver` first — no point re-shipping with feedback pending, and fixing it may invalidate later steps. If no PR/MR yet → `⏭ Skipped — first ship`.

### Step 2 — Mechanical checks
Invoke `mechanical-checks`. Auto-fix the auto-fixables (commit), accumulate the rest. Never blocks.

### Step 3 — Footprint reduction
Invoke `smallest-footprint`. Runs *before* validation — clean the diff, then validate the lean version. Safe findings applied silently; risky findings presented (go/skip/pick).

### Step 4 — Uniformity check
Invoke `uniformity-check`. Auto-applicable alignments applied silently; discussable ones presented with the canonical reference (go/skip/discuss).

### Step 5 — Context validation
Invoke `context-validator`. Scope discipline + code-path analysis automatically, then a ≤5-item human action list. Wait for "Done"/"Found an issue". Blocks if an issue is reported.

### Step 6 — Deep code review
Run whatever deep-review capability the environment has — in priority order:
- a code-review skill/command (e.g. `/code-review`, `/security-review`), or review agents (`code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`, a project auditor), if installed;
- CodeRabbit CLI, if available.
Accumulate findings (confidence ≥ 80%), propose auto-fixes. If none of these exist → `⏭ Skipped — no deep-review tool available`. Never blocks.

### Step 7 — Comment audit
Invoke `comment-audit` — audits *all* comments in changed files (incl. pre-existing ones now stale relative to the diff), not just newly-written ones. Applies approved cut/fix/add.

### Step 8 — Clean history
Invoke `git-clean-history`. Flags WIP/fixup/debug commits and non-conventional messages. Presents squash/rebase/leave options; never auto-squashes.

### Step 9 — PR/MR description
Invoke `mr-description`. Generates/updates the title + description from the final diff and pushes after preview. Runs automatically.

---

## Final report
One section per step that ran: `✅ {label} — {result}`, `⚠️ {label} — {detail}`, `❌ {label} — {blocker}`, or `⏭ Skipped — {reason}`. End with one status line:
```
STATUS: ✅ SHIPPED   |   Auto-fixes: {N}   |   Commits added: {N}
```
Use `❌ BLOCKED` if any step blocked. No decorative boxes, no empty sections.

---

## Why this order
1. **Feedback first** — resolve open review before re-validating; later steps may flag code that's about to change.
2. **Mechanical** — fix the noise so later steps don't re-flag it.
3. **Footprint** — cut cruft before validating; validate the lean version (no point uniformizing dead code).
4. **Uniformity** — align what remains with existing patterns.
5. **Context** — scope + code paths on the clean, aligned diff.
6. **Deep review** — heavy analysis on the final code state.
7. **Comment audit** — once code is final, audit all comments (pre-existing ones may now be stale).
8. **History** — commits are stable once code + comments are validated.
9. **Description** — generated from the final diff, not an intermediate state.

---

## Error handling
| Situation | Action |
|-----------|--------|
| No PR/MR yet | Skip steps 1 & (description still runs to create it) |
| A step's skill not installed | Note `⏭ Skipped — skill not installed`, continue |
| User dismisses a skill mid-flow | Stop pipeline, return to user |
| Step 5 issue reported | Help fix, re-run step 5 |
| CLI unavailable | Fall back to the default branch for `BASE` |
