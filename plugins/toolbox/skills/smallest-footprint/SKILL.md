---
name: smallest-footprint
description: Audit a MR/PR diff and reduce its footprint — removing dead code, collapsing unnecessary abstractions, eliminating duplicates, and simplifying over-engineered patterns. Use when asked to "simplify the MR", "shrink the diff", "reduce footprint", "trim the PR", "clean up dead code in the MR", or when a branch has grown across many iterations and accumulated cruft. Always use this skill for footprint reduction tasks — do NOT freehand a simplification pass without it.
user-invocable: true
---

# Smallest Footprint Skill

I'm using the smallest-footprint skill to audit this MR/PR and reduce its surface area.

**Core principle:** The simplest code that works is the best code. Three similar lines are better than a premature abstraction. One direct function call is better than a configurable factory. If a "simplification" adds indirection, it's not simpler — it's more complex with fewer lines.

**Senior bias: removing beats adding.** A smaller MR is the goal, not a side effect. Each MR should be the *minimum* that delivers its value — anything beyond that minimum is itself the finding. The senior instinct is to delete, not to accumulate: less code is less to read, less to break, less to maintain. So this pass isn't only "trim the edges of what's here" — it's "should this much code exist at all for this much value?"

**When the machinery is disproportionate to the payoff, question the approach, not the lines.** If a marginal improvement takes 15 files, a new store, three new hooks, and a validation layer — that's a signal the *approach* is wrong, not that it needs tidying. The best footprint reduction is often deleting a whole subsystem and doing the thing a simpler way, not shaving 10% off an over-built one. Don't be afraid to flag "this entire mechanism is too much for what it buys — here's the smaller shape."

Analyze the diff first, categorize findings by type and confidence, confirm with the user, then apply only what's approved. Never touch code outside the diff.

## When to Use

- User invokes `/smallest-footprint` or `/smallest-footprint <MR_NUMBER>`
- User asks to simplify, shrink, or trim a MR/branch
- A MR has grown across multiple iterations and likely contains cruft

---

## Step 1: Detect the MR/PR

Auto-detect the change for the current branch using the host CLI (GitLab `glab` or GitHub `gh`):

**GitLab:**
```bash
glab mr view "$(git branch --show-current)" -F json | jq '{iid, title, source_branch, target_branch}'
# by number: glab mr view 1537 -F json | jq '{iid, title, source_branch, target_branch}'
```

**GitHub:**
```bash
gh pr view "$(git branch --show-current)" --json number,title,headRefName,baseRefName
# by number: gh pr view 1537 --json number,title,headRefName,baseRefName
```

**If no MR/PR is found for the current branch, STOP.** Ask the user to provide the number explicitly (e.g. `/smallest-footprint 1537`).

---

## Step 2: Collect the Full Diff

Fetch the complete diff against the target branch:

```bash
git fetch origin
git diff origin/{target_branch}...HEAD
```

Also collect a file summary to know the scope:

```bash
git diff origin/{target_branch}...HEAD --stat
```

Print a brief scope header:
```
MR/PR #{id} "{title}" — {N} files changed, +{additions} / -{deletions}
```

If the diff is empty or the MR/PR has no commits yet, **STOP** and inform the user.

---

## Step 3: Analyse the Diff

Read each changed file in full (not just the diff hunks — context matters). For each file touched by the MR, form an independent opinion on what could be simplified.

Look for findings in these categories:

### 🧹 Dead Code
Variables, constants, imports, functions, types, or components that are introduced in this diff but never referenced — or that existed before and are now fully superseded by changes in this diff.

### 🔀 Single-Use Abstraction
A function, hook, or component extracted in this diff that is called exactly once. Evaluate whether inlining it would make the code clearer without meaningful loss of reusability.

### 🔁 Duplication
Logic that appears in two or more files touched by this diff that could be unified — shared utility, extracted hook, common type.

### 📦 Unnecessary Intermediate
Variables or constants introduced only to be immediately passed somewhere else (e.g. `const result = fn(); return result`). Evaluate whether collapsing them improves readability.

### 🏷️ Verbose Typing
TypeScript types or interfaces that are fully inferrable, redundant `as` casts, or overly explicit generics where the compiler would infer correctly.

### 🩹 Workaround Scaffolding (root-cause smell — highest value)
Code that guards, validates, dedups, or syncs to defend against a *symptom* whose root cause lives elsewhere — usually a band-aid for an earlier choice in the same feature. The tell: the complexity only exists *because of* another decision; undo that decision and the scaffolding deletes itself.

For any defensive / validation / dedup / sync / suppression code, ask: **why does this need to exist?** If the honest answer is *"to paper over X that we introduced,"* the fix is to undo X — not to harden the band-aid. Removing the band-aid without removing X just moves the bug.

- If the root cause is **inside the diff**, propose fixing it — that's the real simplification, and it usually deletes far more than a line-level trim would.
- If the root cause is **outside the diff**, flag it as the real fix to do separately (`📋 Out of scope`) rather than polishing the workaround in place.

**Example:** a read-only calendar preview once validated "is there a unique id, and …" before generating its events. That check made no sense on its own — it only existed because editing had been *allowed*, and every edit duplicated the event when the calendar reopened. The root-cause fix was to disable editing in the read-only preview (lock the focused appointment); doing that deleted the entire id-validation block. Trimming the validation would have been treating the symptom; deleting the reason for it was the senior move.

### 🏗️ Over-Engineered Logic
The most important *line-level* category. Patterns where simpler code does the same thing:

**Premature abstraction:**
- Generic utility that only handles one case — just write the specific code
- Config object or options pattern when there's only one caller with one config
- Factory function that creates one type of thing
- Wrapper component that just passes all props through with one tweak — inline the tweak

**Unnecessary indirection:**
- `useCallback` wrapping a function that's only called in one place and has no deps
- Custom hook that just wraps a single `useState` + one setter — inline it
- Zustand store for state used by exactly one component — use `useState`
- Separate file for a 5-line utility used once

**Defensive overkill:**
- Null checks on data guaranteed by TypeScript types or React Query's `enabled` flag
- Try/catch wrapping code that can't throw
- Fallback values for required fields that are never undefined
- Runtime type guards on data from a typed API response

**Speculative features:**
- Parameters or options that are always passed the same value — hardcode it
- Boolean flags added "for flexibility" with only one call site
- `switch` with one case + default that could be an `if`
- Enum or union type with one member

**Naming a trivial expression:**
- `const isActive = status === 'active'; if (isActive)` — inline it
- `const hasPermission = user.role === 'admin'; return hasPermission` — return the expression
- Exception: keep named vars when the name explains a non-obvious business rule

### 🪓 Over-Scoped Change
A file touched by this diff where the changes appear unrelated to the MR's stated purpose — accidental edits, formatting-only changes that should be a separate commit, or scope creep.

---

## Step 4: Assess Each Finding

For each finding, assign:

**Confidence:**
- `safe` — mechanical change, zero behavioral risk (dead import, inferred type, inline single-use const)
- `risky` — requires judgment (collapsing abstractions, merging logic, removing code that *looks* unused but may have side effects)

**Recommendation:**
- `✅ Simplify` — clear win, belongs in this MR
- `💬 Discuss` — valid but requires human judgment before acting
- `🗑️ Skip` — not worth touching (stylistic, intentional verbosity, or too risky for the gain)

Be direct and opinionated. One-line reason per finding. Don't hedge.

---

## Step 5: Present Triage Table

Show all findings sorted by file using this exact 3-line format per finding:

```
{N}. {recommendation} [{confidence}] — {path/to/file.ext}
   {category icon} {category name} — what was found, anchored to a symbol or line
   → one-line honest take (why simplify, or why it's risky)
```

- Line 1: `recommendation` is `✅ Simplify`, `💬 Discuss`, or `🗑️ Skip`. `confidence` is `safe` or `risky` (omit for `🗑️ Skip`).
- Line 2: cite the actual symbol from the diff (variable name, function, hook). Don't paraphrase to placeholder names.
- Line 3: state the trade-off in one line. No hedging.

After the list:

```
Quick summary: {S} to simplify, {D} to discuss, {K} to skip.
Estimated diff reduction: ~{N} lines.
Default if you say "go": apply all ✅, discuss all 💬, skip all 🗑️.
```

**CRITICAL: STOP HERE. Do NOT proceed to Step 6 without explicit user confirmation.**

Present the table, then WAIT. Ask how to proceed:

- **"Go"** — apply all `✅ Simplify` items as recommended; discuss `💬` items inline before touching them
- **"Apply all"** — apply every finding including risky ones
- **"Let me pick"** — user provides comma-separated numbers
- **"Report only"** — no changes, just the audit

---

## Step 6: Apply Approved Simplifications

For each approved finding:

1. **Re-read the file** before editing — the earlier read may be stale if other fixes were applied
2. **Apply the minimal change** — don't refactor anything outside the finding's described scope
3. **Do not reformat unrelated lines** — this is a footprint reduction pass, not a style pass
4. **Report each change:**
   ```
   Applied #1: src/components/Foo/Bar.tsx — Removed unused import `useOldFormat`
   Applied #2: src/components/Foo/Bar.tsx — Removed redundant type annotation on `items`
   ```

For `💬 Discuss` items: briefly explain the tradeoff and ask for a yes/no before touching the file.

**Never touch files not in the original diff.** If a simplification would require changing a file outside the diff (e.g., a shared utility), flag it as `📋 Out of scope` and skip it.

---

## Step 7: Verify

Run the project's own checks (the same ones CI runs). Detect the toolchain rather than assuming:

```bash
if [ -f package.json ]; then
  npm run check && npm run type-check          # JS/TS — lint/format + types
elif [ -f pyproject.toml ] || [ -f setup.py ] || [ -f manage.py ]; then
  ruff check . && mypy .                        # Python — substitute flake8 / pyright if configured
elif [ -f Cargo.toml ]; then
  cargo clippy && cargo check                   # Rust
elif [ -f go.mod ]; then
  go vet ./... && go build ./...                # Go
else
  echo "unknown toolchain — note in report, don't block"
fi
```

Prefer the project's declared scripts (`package.json` scripts, `Makefile`, CI config) when they exist — they're authoritative for what CI actually runs.

If a simplified file has a corresponding test, run it (e.g. `npm test path/to/related.test.ts`, `pytest path/to/related_test.py`).

If verification fails: identify which simplification introduced the regression, revert that specific change, re-run. If still failing, report and let the user decide. **Never commit broken code.**

---

## Step 8: Commit

Group all applied simplifications into a single atomic commit:

```bash
git add -A
git commit -m "refactor: reduce MR footprint — remove dead code and simplify types

- {one line per applied finding}
"
```

Use `refactor:` prefix. Keep the commit message factual — list what was removed/simplified, not why.

Report when done:
```
Applied {N} simplification(s). Diff reduced by ~{X} lines.
Committed as: refactor: reduce MR footprint — ...
```

---

## Error Handling

| Condition | Action |
|-----------|--------|
| No MR/PR found for current branch | **STOP** — "No MR/PR found for branch `{branch}`. Provide the number: `/smallest-footprint <NUMBER>`" |
| Host CLI not authenticated | **STOP** — "Run `glab auth login` / `gh auth login` first." |
| Empty diff | **STOP** — "No changes found between this branch and `{target_branch}`." |
| Finding requires changing a file outside the diff | **SKIP** — Flag as out of scope, do not touch |
| Verification fails after retry | **WARN** — Report failing checks, revert the offending simplification, let user decide |
| User says "report only" | **DONE after Step 5** — No commits, no edits |

---

## Category Reference

| Icon | Category | Confidence default | Example |
|------|-----------|--------------------|---------|
| 🩹 | Workaround Scaffolding | risky | Validation/dedup/sync that only exists to paper over an earlier choice — fix the root cause, the code deletes itself |
| 🧹 | Dead Code | safe | Imported symbol never used after refactor |
| 🔀 | Single-Use Abstraction | risky | Hook or util called exactly once |
| 🔁 | Duplication | risky | Same logic in two touched files |
| 📦 | Unnecessary Intermediate | safe | `const x = fn(); return x` → `return fn()` |
| 🏷️ | Verbose Typing | safe | Explicit type that TypeScript infers |
| 🏗️ | Over-Engineered Logic | risky | Factory for one type, hook wrapping one useState, null check on non-null type |
| 🪓 | Over-Scoped Change | — | Unrelated file touched; flag only, don't fix |

## Self-Check: Am I Adding Complexity?

Before proposing any simplification, ask: **does the "simpler" version actually have fewer concepts?**

A refactoring that extracts a shared utility to eliminate 3 repeated lines has added:
- A new file
- A new import in each consumer
- A new function signature to understand
- A new name to remember

That's 4 new concepts to save 6 lines. The 3 repeated lines were simpler.

**The test:** Could a new developer read the "simplified" version faster than the original? If not, it's not simpler.
