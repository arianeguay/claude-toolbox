---
name: comment-audit
description: Use when validating code comments in a diff/PR/MR before merge — audits changed files for redundant, stale, missing, or over-documented comments. Triggers - "audit comments", "validate comments", "check comments", or before opening a PR/MR on a codebase that values signal over narration.
user-invocable: true
---

# Comment Audit

Audit comments in the changed files against the project's comment standards. On a senior codebase, **too many comments is as bad as too few** — every comment should teach something the code cannot. Default to cutting: when a finding is borderline between `keep` and `cut`, cut it. A small senior team skims code, not comment blocks — comments only earn their place by teaching something the code can't say alone.

## When to Use
- `/comment-audit` or `/comment-audit <PR/MR_NUMBER>`
- Asked to validate/audit/check comments
- Before merge on a branch with significant new code

---

## Step 1 — Diff scope (provider-agnostic)

```bash
BASE=$(gh pr view "$(git branch --show-current)" --json baseRefName -q .baseRefName 2>/dev/null) \
  || BASE=$(glab mr view "$(git branch --show-current)" -F json 2>/dev/null | jq -r '.target_branch // empty') \
  || true
BASE=${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)}
git fetch -q origin "$BASE" 2>/dev/null || true
git diff "origin/$BASE...HEAD" --stat
```
If empty → STOP, nothing to audit.

---

## Step 2 — Read changed files in full

For each file in the diff, read the **entire file** (not just the hunks) — comments need surrounding code to judge.

---

## Step 3 — Load the project's comment standards

Read the repo's convention docs (`CLAUDE.md`/`AGENTS.md`/`CONTRIBUTING.md`), specifically any "comments / documentation" section. If the repo states rules, they are the source of truth and override the generic principles below.

---

## Step 4 — Analyse comments (new AND pre-existing in changed files)

| Icon | Category | Description |
|------|----------|-------------|
| 🔊 | **Noise** | Restates the obvious — `setIsOpen(true); // set isOpen to true`. Readers read code, not narration. |
| 💀 | **Stale** | Doesn't match the implementation — wrong param names, outdated behavior, copy-paste leftovers. |
| 👻 | **Missing** | Non-obvious logic with no "why" — business rules, workarounds, implicit coupling, side effects. |
| 💣 | **Rot risk** | Will go stale when code changes — references specific versions, hardcoded values, unenforced assumptions. |
| 📚 | **Over-doc** | Excessive doc-comments on simple functions, `@param` that mirrors the type signature, blocks on self-evident code, or a valid multi-fact WHY comment padded with connective prose instead of one tight clause per fact. |
| 🚫 | **Bad TODO** | TODO with no tracker reference or vague removal condition. Match the repo's convention (e.g. `TODO(ABC-123):` or `TODO(#123):`). |

**Decision guide:** explaining WHAT → is the code self-evident? yes → 🔊 cut; no → keep. Explaining WHY → still accurate? no → 💀 fix/remove; yes but prose exceeds one clause per fact → 📚 compress (keep every fact, cut connective filler). A TODO → has a reference? no → 🚫 fix.

**Severity:** `cut` (remove — zero value or misleading) · `fix` (rewrite — intent valid, execution wrong) · `compress` (accurate, non-stale, but longer than one clause per fact, or restated near-verbatim in a sibling file) · `add` (missing "why" for non-obvious logic) · `note` (flag only).

**Mandatory compress pass — do not skip:** "accurate" is not the same as "done." Every comment that survives the 🔊/💀/🚫 filters as a `keep` still owes one more check: count its sentences against its facts. >1 sentence per fact, or any connective tissue ("so that", "which means", "in other words") → `compress`, don't leave it as `keep`. This is the pass that gets skipped when a comment is true and non-redundant — verified-accurate is exactly when reviewers stop scrutinizing and let bloat through.
Also check duplication across the diff: if two-plus files in the same diff carry the same rationale restated in their own words (e.g. three hooks each explaining "why this guard exists" in full), that's `compress` too — the rationale belongs in one place (the shared function/hook/base it's about), with siblings pointing at it in a clause, not repeating it.

---

## Step 5 — Triage table

```
{N}. {severity} [{icon} {category}] — {path}:{line}
   "{quoted comment, or 'missing'}" — {what the code actually does}
   → one-line take (why cut/fix/add)
```
Summary + `Default if you say "go": apply cuts and fixes, show additions for approval.`

**STOP — wait for explicit confirmation.** Options: **Go** (apply cut+fix, propose adds one by one) · **Apply all** · **Let me pick** · **Report only**.

---

## Step 6 — Apply approved changes

Re-read the file, apply the **minimal** change (comment only — never refactor or reformat surrounding code), propose `add` text inline before writing. Report each change.

---

## Step 7 — Verify & commit

Run the repo's own checks on touched files (lint/format, types — detect from the project). Stage only the files actually edited (never `git add -A`), then:
```
docs: audit comments — remove noise, fix stale, add missing
- {one line per applied finding}
```

---

## Guiding principles (generic; repo docs win)

1. **Document "why", not "what"** — if the code says it, the comment shouldn't.
2. **Verify accuracy** — a wrong comment is worse than none.
3. **Document assumptions & edge cases** — preconditions, implicit coupling.
4. **No redundant narration** — self-evident code needs none.
5. **Prevent rot** — link a tracker ref, state the removal condition.
6. **Document side effects** — state mutations, cache invalidations, emitted events.
7. **Business-logic rationale** — explain the domain rule, not the mechanics.
8. **Document implicit coupling** — when two pieces must stay in sync without type enforcement.
9. **Know when NOT to comment** — self-evident code, simple getters, type-documented interfaces.
10. **Keep WHY comments dense** — one tight clause per fact, no padded connective prose, even when a comment legitimately covers several facts.

**Golden rule:** every comment should teach something the code cannot. If it doesn't, it's noise.
