---
name: context-validator
description: Use before submitting a diff/PR/MR to validate what can't be automated — checks scope discipline and code paths automatically, then gives a short, specific, do-this-exactly action list for the human (never a vague checklist). Triggers - "context validation", "validate before review", "what do I need to test".
user-invocable: true
---

# Context Validator

Validate a change before review. **Automate everything possible, then hand the human a concrete action list — not a checklist to think about.**

**For the human steps: be ultra-specific.** Not "test the orders page" but "open `/orders`, click an order with line items, verify the tooltip shows the new field." Every step must be executable without interpretation — no ambiguity, no open-ended questions, nothing left to the reader's judgment.

This is the judgment-level pre-review pass. Pair it with `toolbox:mechanical-checks` (objective violations) and `toolbox:uniformity-check` / `toolbox:smallest-footprint` (drift + size).

---

## Step 1 — Diff scope (provider-agnostic)

```bash
BASE=$(gh pr view "$(git branch --show-current)" --json baseRefName -q .baseRefName 2>/dev/null) \
  || BASE=$(glab mr view "$(git branch --show-current)" -F json 2>/dev/null | jq -r '.target_branch // empty') \
  || true
BASE=${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)}
git fetch -q origin "$BASE" 2>/dev/null || true
DIFF="origin/$BASE...HEAD"
git diff "$DIFF" --name-only
```

If empty → `✅ No changes` and exit.

---

## Step 2 — Scope discipline (automated)

Compare what the diff *touches* against what the change was *supposed* to do. Find the intended scope in this priority order:

1. **A shaping bundle**, if you use one — a local file keyed by the ticket id (`${SHAPING_DIR}/<TICKET>.md`, see `PROFILE.md`). Use its "ship / don't-ship" scope sections; honour a `Reshape` section as the newer source of truth.
2. **The linked issue / PR / MR description** — `gh pr view --json body` or `glab mr view`, or the tracker issue if the branch encodes one (`[A-Z]+-[0-9]+`).
3. **The branch name + commit messages**, as a last resort.

**Flag as scope creep:** files in a different feature domain than the task; new components/utils the task doesn't require; "happened to be nearby" refactors; anything explicitly listed as out-of-scope.
**Not scope creep:** a bug fix in a file you're already editing; a type fix needed to make the feature compile; import cleanup in touched files.

```
── Scope ────────────────────────────────────────────────
  Intent source: {bundle / PR body / issue / branch}
  Files in diff: 12 — in scope: 10
  ⚠️ 2 outside scope:
    - src/.../OrderList.tsx — unrelated filter refactor
  → Recommendation: revert these, file a separate task
```
Or: `✅ All changes within scope`.

---

## Step 3 — Missing-tests check (universal)

If the diff changes logic but adds no test, flag it:
```bash
git diff "$DIFF" --name-only | grep -qiE '(test|spec)' || echo "No test files in diff — confirm intentional"
```
Ask once: intentional (one-shot migration, config, pure styling) → accept with reason; otherwise tests are a blocker before shipping.

---

## Step 4 — Project docs (if configured)

If `PROFILE.md` lists `PROJECT_DOCS`, read each listed path that exists in the repo and scan the diff for anything that contradicts it — a documented edge case ignored, a canonical pattern diverged from, a known workaround flagged as if it were new. Skip silently if `PROJECT_DOCS` is empty, or a listed path doesn't exist.

```
── Project docs ──────────────────────────────────────────
  ✅ docs/EDGE_CASES.md — no contradictions
  ⚠️ docs/TEST_GUIDELINES.md — mock pattern diverges from canonical example (§3)
```

---

## Step 5 — Per-stack analysis + targeted questions

Detect the stack(s) from the diff and **read `stacks/<stack>.md`**; it lists the stack's *automated* analyses (which I run and report) and the *targeted human questions* (which I ask only when the trigger files are present).

| Files in diff | Stack file |
|---------------|-----------|
| `*.tsx`/`*.ts` + Tailwind | `stacks/ts-react-tailwind.md` |
| `*.ts` (no React) | `stacks/ts-node.md` |
| `*.py` | `stacks/python.md` |
| `*.php` | `stacks/php.md` |

Run the automated analyses first and report findings inline — they *replace* questions ("did you test the loading state?" → I read the code instead).

---

## Step 6 — Human action list (only what truly can't be automated)

```
── Things you need to do (I can't check these) ──────────
1. OPEN localhost:3000/orders/<an order with line items>
   → CLICK the Activity tab
   → VERIFY entries show with correct dates (not UTC-shifted)
2. OPEN the same page as a read-only role
   → VERIFY the Activity tab is NOT visible (admin-only)
That's it — 2 things.
```
**Rules:** max 5 items · each starts with a verb (OPEN/CLICK/TYPE/VERIFY/RESIZE) · each names the exact page/component + what to check · never "does it look right?" · if a test or an automated analysis already covers it, don't ask. If nothing is human-only: `✅ None needed — all verifiable paths covered automatically.`

---

## Step 7 — Confirm

`AskUserQuestion` with exactly two options: **"Done"** / **"Found an issue"**. No item-by-item interrogation. If an issue → help fix, re-run. If done → final report:

```
Context Validator — {branch}
── Scope ──────────  ✅ within scope
── Tests ──────────  ✅ present / ⚠️ none (justified: …)
── Project docs ───  ✅ no contradictions / ⏭ none configured
── [stack] analysis  ✅ no race/undefined-data paths
── Human checks ───  ✅ 2/2 confirmed
────────────────────────────────────────────────────────
Status: ✅ PASSED
```

---

## Notes

- **Doesn't block on vague concerns** — only on specific, actionable issues (missing tests for logic, an untested non-reversible migration, confirmed scope creep).
- The human list is a *last resort*, not the main event. Automate first.
- Scope discipline is the highest-value automated check — it catches creep before a reviewer does.
