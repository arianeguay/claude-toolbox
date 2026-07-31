---
name: mechanical-checks
description: Use before submitting a diff/PR/MR to catch mechanical violations a reviewer or bot would otherwise flag — debug statements, hardcoded secrets, TODOs without a tracker reference, leftover conflict markers, plus per-stack checks (Tailwind, aria-labels, i18n parity, missing migrations, N+1, Celery). Triggers - "mechanical checks", "pre-review checks", "what would the bot flag".
user-invocable: true
---

# Mechanical Checks

Pre-review mechanical scan. Catches the small violations that otherwise land as bot comments (CodeRabbit, Bugbot) or CI failures — *before* you open the PR/MR.

**Mechanical, not judgmental.** This skill checks for objective violations (a left-in `print`, a missing `aria-label`, an unbalanced locale file). It does **not** judge logic, architecture, or style — for that use `smallest-footprint` and `uniformity-check`.

**Adaptive.** Each check runs only if the diff touches relevant files. A diff with no Python runs no Python checks. A monorepo diff that touches both `*.tsx` and `*.py` runs both stacks.

---

## Step 1 — Diff scope (provider-agnostic)

```bash
BASE=$(gh pr view "$(git branch --show-current)" --json baseRefName -q .baseRefName 2>/dev/null) \
  || BASE=$(glab mr view "$(git branch --show-current)" -F json 2>/dev/null | jq -r '.target_branch // empty') \
  || true
BASE=${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)}
git fetch -q origin "$BASE" 2>/dev/null || true
DIFF="origin/$BASE...HEAD"
git diff "$DIFF" --name-only        # the changed files — drives which checks run
```

If no files changed → `✅ No changes — mechanical checks skipped` and exit.

---

## Step 2 — Detect stacks in the diff

Map changed files to stacks; run the checks from **every** matching `stacks/*.md`:

| Files in diff | Stack checks |
|---------------|--------------|
| `*.tsx` / `*.ts` + Tailwind config | `stacks/ts-react-tailwind.md` |
| `*.ts` (no React) | `stacks/ts-node.md` |
| `*.py` | `stacks/python.md` |
| `*.php` | `stacks/php.md` |

Print a header before running:
```
Mechanical checks — {branch} → {BASE}
Active: {checks that will run, given the diff}
Skipped: {checks + why}
```

---

## Step 3 — Universal checks (language-agnostic, always run on a non-empty diff)

**U1 — Leftover conflict markers**
```bash
git diff "$DIFF" | grep -nE '^\+(<<<<<<<|=======|>>>>>>>)' && echo "CONFLICT MARKERS FOUND"
```

**U2 — TODO/FIXME without a tracker reference**
```bash
# Flags added TODO/FIXME with no JIRA-style key (ABC-123) and no issue ref (#123).
git diff "$DIFF" | grep '^+' | grep -iE 'TODO|FIXME' | grep -vE '[A-Z]{2,}-[0-9]+|#[0-9]+'
```
The accepted reference format is repo-specific — check the repo's `CLAUDE.md`/`AGENTS.md` (or `TICKET_PREFIX` in `PROFILE.md`) for its convention (e.g. `ABC-1234`, `#123`) and adjust the negative pattern.

**U3 — Hardcoded secrets**
```bash
git diff "$DIFF" | grep '^+' | grep -iE '(password|secret|api_?key|token)\s*[:=]\s*["\x27][^"\x27]{8,}'
```
Flag literal credentials (not a variable, env read, or placeholder). Auto-fix: replace with an env/config read.

---

## Step 4 — Per-stack checks

For each stack detected in Step 2, **read `stacks/<stack>.md` and run its checks** against `$DIFF`. Each stack file lists its checks with exact grep/script recipes and which are auto-fixable. Skip any check whose trigger files aren't in the diff (report as `⏭ Skipped — reason`).

---

## Step 5 — Report

```
Mechanical Checks — {branch}

── Conflict markers (U1) ────────────────────────────────
  ✅ none
── TODO without ticket (U2) ─────────────────────────────
  ❌ src/api/foo.ts:88  // TODO: handle edge case → needs a tracker ref
── Secrets (U3) ─────────────────────────────────────────
  ✅ none
── [stack: ts-react-tailwind] Tailwind ──────────────────
  ❌ src/components/Foo.tsx  bg-slate-200/05 → should be /5
── [stack: ts-react-tailwind] aria-labels ───────────────
  ❌ src/components/Bar.tsx  icon-only <Button> without aria-label (~L42)
── [stack: python] migrations ───────────────────────────
  ⏭ Skipped — no models changed
──────────────────────────────────────────────────────────
N issue(s) — fix before review
```

Then offer to auto-fix the auto-fixable ones (the stack file marks which: import rewrites, missing locale keys, `print`/`console.log` removal, TODO format, wildcard imports).

---

## Notes

- Heuristic checks (N+1, missing migrations) produce false positives — report them as **warnings**, not blockers.
- Universal checks (U1–U3) and most stack checks read the **diff only**; i18n parity reads whole locale files.
- When you learn a repo-specific mechanical rule worth reusing, add it to the matching `stacks/*.md` (or the repo's own docs).
