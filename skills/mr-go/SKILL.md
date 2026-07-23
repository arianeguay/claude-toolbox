---
name: mr-go
description: Use when a draft MR is ready to move to ready-for-review — after mr-ship has already validated the code and additional changes have been made since. Validates the delta and reports readiness; never flips draft state automatically — the user does that themselves.
user-invocable: true
---

# MR Go

Lightweight pre-review gate. Assumes `mr-ship` already ran once on this branch. Skips the heavy pipeline (footprint, uniformity, full review) — those don't need re-running unless you've refactored substantially since.

**Scope:** noether (React frontend).

**When to use vs `mr-ship`:**
- `mr-ship` → first time creating the MR (full pipeline)
- `mr-go` → validating that the MR is ready for review after fixes/polish (Ariane removes draft herself)

**Never auto-remove draft.** Ariane flips draft state manually — or explicitly asks. This skill validates and reports readiness only.

**When to use `mr-ship` instead:** if you've refactored substantially since the last ship (new files, renamed abstractions, big structural changes), run `mr-ship` again — uniformity/footprint are worth re-running.

---

## Pipeline

```
1. Mechanical checks    → i18n parity, aria-labels, imports, Tailwind
2. Type-check + lint    → npm run check:fix && npm run type-check
3. History clean-up     → flag WIP/debug/non-conventional commits
4. MR description       → detect if stale; update only if commits added new surfaces
5. Report readiness     → tell user the MR is ready; user removes draft themselves
```

---

## Step 0 — Setup

```bash
TARGET=$(glab mr view $(git branch --show-current) -F json 2>/dev/null | jq -r '.target_branch // empty')
TARGET=${TARGET:-develop}
git fetch origin "$TARGET"

BRANCH=$(git branch --show-current)
MR_IID=$(glab mr view "$BRANCH" -F json 2>/dev/null | jq -r '.iid // empty')
```

Show:
```
MR Go — {branch} → {TARGET}
```

If no MR exists (`MR_IID` empty) → error: "No MR found for this branch. Run /mr-ship first."

---

## Step 1 — Mechanical checks

Invoke `mechanical-checks`.

- **Auto-fixable** (relative imports, i18n parity) → fix, commit, continue
- **Not auto-fixable** (missing aria-label) → accumulate in report, continue

> Never blocks. Accumulates findings.

---

## Step 2 — Type-check + lint

```bash
npm run check:fix
npm run type-check
```

- If `check:fix` produces changes → commit as `chore: fix lint/format`
- If `type-check` fails → show errors, stop pipeline, ask user to fix

> Blocks only on type errors.

---

## Step 3 — History clean-up

Invoke `my-git-clean-history`.

Flags WIP / debug / fixup commits and non-conventional messages. If clean → continue silently. If dirty → show audit, ask "squash / rebase / leave it".

> Never blocks automatically.

---

## Step 4 — MR description

Check if the MR description is stale by comparing the current diff surfaces against what the description covers:

```bash
# Commits since last description update (heuristic: since last "docs(mr):" or "chore(mr):" commit, or all if none)
git log develop..HEAD --oneline | head -10
```

- **No new surfaces** (only fixes/polish since last description) → `⏭ Skipped — description up to date`
- **New surfaces added** (new components, new flows) → invoke `my-mr-description` to regenerate

> Never blocks.

---

## Step 5 — Report readiness

**Do NOT flip draft state.** Ariane removes draft manually (or explicitly asks "remove draft").

Check the current draft state and report it — never call `glab mr update --title` to strip the prefix, never pass `--ready`.

```bash
CURRENT_TITLE=$(glab mr view "$MR_IID" -F json | jq -r '.title')
MR_URL=$(glab mr view "$MR_IID" -F json | jq -r '.web_url')

if [[ "$CURRENT_TITLE" == Draft:* ]]; then
  echo "✅ Validation passed — MR is ready for review"
  echo "   Still in Draft. Remove draft when you're ready: $MR_URL"
else
  echo "✅ Validation passed — MR is already out of draft"
fi
```

If the user explicitly asks to remove draft in this same turn ("and remove draft", "flip it ready", etc.), only then run the strip. Otherwise leave it.

---

## Final Report

```
MR Go — {branch}

── Mechanical checks ─────  ✅ / ⚠️ {findings}
── Type-check + lint ─────  ✅ Clean / ❌ {errors}
── History ───────────────  ✅ Clean / ⚠️ {commits}
── MR description ────────  ✅ Up to date / ✅ Updated
── Draft state ───────────  ⏸ Still Draft — user to flip / ✅ Already ready

STATUS: ✅ VALIDATED  |  Auto-fixes: {N}  |  Commits added: {N}
Next: remove draft on GitLab when ready → {MR_URL}
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| No MR found | Stop, tell user to run /mr-ship first |
| type-check fails | Block, show errors |
| history dirty | Show audit, offer options |
| description stale | Regenerate, don't block |
| Draft already removed | Note it, continue |
| User asks "remove draft" explicitly | Only then strip the "Draft: " prefix |
