---
name: mr-ship
description: Use when ready to submit a PR/MR for review — runs the pre-review pipeline at one of three depths (full/medium/short). Full validates a complex new PR, medium a moderate one or a delta on an already-validated PR, short a trivial PR or the final gate before flipping draft to ready. Triggers - "ship it", "ready for review", "run the pre-review pipeline", "/mr-ship short".
user-invocable: true
---

# Ship (pre-review pipeline)

One command from "code done" to "ready for review." Runs the toolbox skills in order, fixes what it can, tells you exactly what it can't. Provider-agnostic (GitHub `gh` / GitLab `glab`).

**Ship-only-what's-asked:** the pipeline catches scope creep, over-engineering, and cruft, then cuts it before the reviewer sees it.
**Automate everything possible;** when the pipeline needs a human, say exactly what to do — not what to think about.

Each step **invokes another toolbox skill** — this file is just the orchestration and order. If a step's skill isn't installed, note it and continue.

---

## Modes

Three depths. The axis is **how much human judgment the run involves** — which is also what makes the shallow modes fast.

| Mode | What it covers | Human actions |
|---|---|---|
| **short** | Mechanical and objective only. Nothing that needs a judgment call. | **0** |
| **medium** | short + diff hygiene (size, consistency, comments). Decisions about code, nothing to test off-screen. | **≤2** |
| **full** | medium + judgment and human validation (scope, code paths, deep review). The only mode that sends you into the app. | **≤5** |

### Picking a mode

Explicit argument wins: `/mr-ship short`. With no argument, suggest one from what Step 0 already computed, print the reason, and let the user override:

| Situation | Suggest |
|---|---|
| No PR/MR yet + large diff or new abstractions | **full** |
| No PR/MR yet + small diff, no new component | **medium** |
| PR/MR exists + new surfaces since the last ship | **medium** |
| PR/MR exists + only fixes/polish since the last ship | **short** |
| PR/MR exists, in draft, flipping to ready | **short** |

Print one line and proceed: `Mode: medium (MR exists, 3 files, no new surface) — override: /mr-ship full`.

Suggest, never gate. If the user named a mode, do not second-guess it.

### What runs where

| # | Step | Skill | short | medium | full | Blocks? |
|---|------|-------|:--:|:--:|:--:|---------|
| 0 | Setup + behind-base guard | — | ✅ | ✅ | ✅ | **always** |
| 1 | Resolve review feedback (iterations only) | `review-comments-resolver` | ✅ | ✅ | ✅ | only if user dismisses |
| 2 | Mechanical checks | `mechanical-checks` | ✅ | ✅ | ✅ | never (accumulates) |
| 3 | Type-check + lint | — | ✅ | ✅ | ✅ | on type errors |
| 4 | Footprint reduction | `smallest-footprint` | ⏭ | ✅ | ✅ | only on risky findings |
| 5 | Uniformity check | `uniformity-check` | ⏭ | ✅ | ✅ | only on discussable findings |
| 6 | Comment audit | `comment-audit` | ⏭ | ✅ | ✅ | only if user dismisses |
| 7 | Context validation | `context-validator` | ⏭ | ⏭ | ✅ | only if user reports an issue |
| 8 | Deep code review | *(see Step 8)* | ⏭ | ⏭ | ✅ | never (accumulates) |
| 9 | Clean history | `git-clean-history` | ✅ | ✅ | ✅ | never (presents options) |
| 10 | PR/MR description | `mr-description` | ✅ | ✅ | ✅ | runs automatically |
| 11 | Draft state report | — | ✅ | ✅ | ✅ | never |

Three deliberate choices:

- **Step 0 runs in every mode.** It is a correctness guard, not a validation — it is never optional.
- **Step 1 runs in every mode**, including short. Flipping draft→ready with unresolved review comments is the exact accident short exists to prevent.
- **Steps 7 and 8 are the only ones medium drops.** They are the two that cost the most *and* demand your attention. That is what makes medium fast.

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
Show: `Ship — {branch} → {BASE} ({FILES} files)`. Detect whether a PR/MR already exists (`gh pr view "$BRANCH"` / `glab mr view "$BRANCH"`) — this drives both Step 1 and the mode suggestion.

### Step 0.1 — Behind-base guard (BLOCKS — never skip, any mode)
Every pipeline step diffs with three-dot (`origin/$BASE...HEAD`), which compares against the **merge-base** and so is *blind* to commits that landed on the base after you forked. If the branch is behind base, a later `git reset --soft origin/$BASE` (or a naive squash) silently re-parents a stale tree onto the new base and turns already-merged work into phantom **deletions** — invisible to every three-dot check in this pipeline.

```bash
BEHIND=$(git rev-list --count "HEAD..origin/$BASE")
echo "Behind $BASE by: $BEHIND commit(s)"
git merge-base --is-ancestor "origin/$BASE" HEAD && echo "up to date with base" || echo "BEHIND BASE"
```
If `BEHIND` > 0 → **STOP the pipeline.** The branch must be rebased before shipping:
```bash
git rebase "origin/$BASE"   # replays commits, surfaces conflicts/drops — unlike reset --soft, which absorbs them
```
Then re-run mr-ship from Step 0. Do **not** proceed while behind — and do **not** use `git reset --soft origin/$BASE` to squash a behind branch. As a final belt-and-suspenders before any push, confirm the **two-dot** diff has no files you didn't touch (two-dot shows base-advance deletions that three-dot hides): `git diff "origin/$BASE" HEAD --stat`.

Prevention upstream of this skill: cut worktrees/branches from the fetched remote ref (`git fetch origin && git worktree add -b x ../wt origin/$BASE`), not from a possibly-stale local branch.

---

## Step 1 — Resolve review feedback (iterations only) — *all modes*
If a PR/MR already exists, invoke `review-comments-resolver` first — no point re-shipping with feedback pending, and fixing it may invalidate later steps. If no PR/MR yet → `⏭ Skipped — first ship`.

## Step 2 — Mechanical checks — *all modes*
Invoke `mechanical-checks`. Auto-fix the auto-fixables (commit), accumulate the rest. Never blocks.

## Step 3 — Type-check + lint — *all modes*
Run the repo's check commands. Read them from `PROFILE.md` (`LINT_CMD`, `TYPECHECK_CMD`) if present; otherwise detect from the manifest (`package.json` scripts, `Makefile`, `pyproject.toml`, `composer.json`). If neither yields a command → `⏭ Skipped — no check command found`; do not invent one.

- Lint/format autofix produces changes → commit as `chore: fix lint/format`
- Type-check fails → show errors, **stop the pipeline**, ask the user to fix

> The only step that blocks on its own findings. Cheap, objective, and a reviewer will hit it anyway.

## Step 4 — Footprint reduction — *medium, full*
Invoke `smallest-footprint`. Runs *before* validation — clean the diff, then validate the lean version. Safe findings applied silently; risky findings presented (go/skip/pick).

## Step 5 — Uniformity check — *medium, full*
Invoke `uniformity-check`. Auto-applicable alignments applied silently; discussable ones presented with the canonical reference (go/skip/discuss).

## Step 6 — Comment audit — *medium, full*
Invoke `comment-audit` — audits *all* comments in changed files (incl. pre-existing ones now stale relative to the diff), not just newly-written ones. Applies approved cut/fix/add.

## Step 7 — Context validation — *full only*
Invoke `context-validator`. Scope discipline + code-path analysis automatically, then a ≤5-item human action list. Wait for "Done"/"Found an issue". Blocks if an issue is reported.

## Step 8 — Deep code review — *full only*
Run whatever deep-review capability the environment has — in priority order:
- a code-review skill/command (e.g. `/code-review`, `/security-review`), or review agents (`code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`, a project auditor), if installed;
- CodeRabbit CLI, if available.

Accumulate findings (confidence ≥ 80%), propose auto-fixes. If none of these exist → `⏭ Skipped — no deep-review tool available`. Never blocks.

## Step 9 — Clean history — *all modes*
Invoke `git-clean-history`. Flags WIP/fixup/debug commits and non-conventional messages. Presents squash/rebase/leave options; never auto-squashes.

> Its rewrite scope is `merge-base(HEAD, origin/$BASE)..HEAD` — the whole branch, not `@{upstream}..HEAD`. A scope limited to unpushed commits makes the audit look clean on a branch that isn't.

## Step 10 — PR/MR description — *all modes*
Invoke `mr-description`. Generates/updates the title + description from the final diff and pushes after preview.

In **short** mode, skip the regeneration when nothing new surfaced (only fixes/polish since the last description) → `⏭ Skipped — description up to date`. Judge from the diff surfaces, not from commit-message conventions.

## Step 11 — Draft state report — *all modes*
**Never flip draft state.** Report it; the user flips it themselves.

```bash
# GitHub
gh pr view "$BRANCH" --json isDraft,url -q '[.isDraft, .url] | @tsv'
# GitLab
glab mr view "$BRANCH" -F json | jq -r '[(.title|startswith("Draft:")), .web_url] | @tsv'
```

- Still draft → `⏸ Validation passed — still in Draft. Flip it when you're ready: {url}`
- Already out of draft → `✅ Validation passed — already ready for review`

Only strip the draft prefix / pass `--ready` if the user asks for it **in the same turn** ("and flip it ready"). Otherwise leave it alone.

---

## Final report
One section per step that ran: `✅ {label} — {result}`, `⚠️ {label} — {detail}`, `❌ {label} — {blocker}`, or `⏭ Skipped — {reason}`. Steps excluded by the mode are not listed as skips — name the mode instead.

```
STATUS: ✅ SHIPPED (medium)   |   Auto-fixes: {N}   |   Commits added: {N}
```
Use `❌ BLOCKED` if any step blocked. No decorative boxes, no empty sections.

---

## Why this order
1. **Feedback first** — resolve open review before re-validating; later steps may flag code that's about to change.
2. **Mechanical** — fix the noise so later steps don't re-flag it.
3. **Type-check + lint** — fail fast on objective breakage before spending effort on judgment passes.
4. **Footprint** — cut cruft before validating; validate the lean version (no point uniformizing dead code).
5. **Uniformity** — align what remains with existing patterns.
6. **Comment audit** — once code is settled, audit all comments (pre-existing ones may now be stale).
7. **Context** — scope + code paths on the clean, aligned diff.
8. **Deep review** — heavy analysis on the final code state.
9. **History** — commits are stable once code + comments are validated.
10. **Description** — generated from the final diff, not an intermediate state.

---

## Error handling
| Situation | Action |
|-----------|--------|
| No PR/MR yet | Skip step 1 (description still runs to create it) |
| A step's skill not installed | Note `⏭ Skipped — skill not installed`, continue |
| No lint/type-check command found | Note `⏭ Skipped`, continue — never invent one |
| User dismisses a skill mid-flow | Stop pipeline, return to user |
| Step 7 issue reported | Help fix, re-run step 7 |
| CLI unavailable | Fall back to the remote default branch for `BASE` |
| User asks to flip draft explicitly | Only then strip the draft state |
