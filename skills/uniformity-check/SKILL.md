---
name: uniformity-check
description: Use after writing or before submitting a diff to verify new code matches the rest of the codebase — no reinvented utilities, no convention drift, no architectural or styling divergence, no UI placement drift. Triggers - "uniformity check", "is this consistent with the rest?", "does this match how we do it?", "check for drift".
user-invocable: true
---

# Uniformity Check

I'm using the uniformity-check skill to verify a diff doesn't drift from the codebase's existing patterns.

**Core mentality:** *Every time you add something, check how it's done elsewhere first — because it's already been thought about.* Assume the problem has been solved: someone reasoned through the tradeoffs and the codebase carries that reasoning in its helpers, hooks, components, naming, file layout, and UI placement. New code that ignores those decisions isn't fresh thinking — it's parallel reinvention that fragments the codebase and makes reviewers ask *"why didn't they use what's already there?"*

The default posture is **"this already exists — find it"**, not **"this is new — justify a search."** Original-looking code is a smell; search harder before accepting it. **This applies to design too:** a button's corner, a label's position, a dialog's footer order, a list's density — there's a precedent. Find the closest comparable surface and match it, or justify the divergence with a citation.

**Core principle:** New code should look like it belongs. If the codebase already solves a problem, the diff should use that solution — not invent a new one.

**This is a quality gate, not a correctness gate.** Never block; if the user disagrees with a finding, skip it.

---

## Sources of truth (in priority order)

1. **The repo's own convention docs** — `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/*`, `CONTRIBUTING.md`, `.editorconfig`, linter config. These are authoritative; they override any generic baseline.
2. **Sibling files** — the closest comparable code/UI in the same folder family or the same interaction across modules. The living precedent.
3. **The stack baseline** — `stacks/<stack>.md` in this skill. A generic checklist of what *kinds* of drift to look for per stack. A starting point, not the last word — extend it per repo.

When 1 and 3 conflict, 1 wins. Always.

---

## When To Use

- After writing a chunk of new code, before opening a PR/MR on a codebase with established conventions
- Standalone: "is this consistent?", "does this match how we usually do it?", "uniformity check"
- As a step inside a larger ship pipeline (after footprint reduction, before final review)

---

## Step 1 — Detect the diff scope

Provider-agnostic. Find the base branch, then the changed files:

```bash
# Base branch: PR/MR target if available, else upstream, else the remote default
BASE=$(gh pr view "$(git branch --show-current)" --json baseRefName -q .baseRefName 2>/dev/null) \
  || BASE=$(glab mr view "$(git branch --show-current)" -F json 2>/dev/null | jq -r '.target_branch // empty') \
  || true
BASE=${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)}
git fetch -q origin "$BASE" 2>/dev/null || true
FILES=$(git diff "origin/$BASE...HEAD" --name-only)
```

If no files changed → `✅ No changes — uniformity check skipped` and exit.

---

## Step 2 — Load the conventions

1. **Read the repo's convention docs** (Source 1 above) — whichever exist. Treat their rules as binding.
2. **Detect the stack** and read the matching baseline:

| Signal | Stack file |
|--------|-----------|
| `package.json` has `react` + a Tailwind config | `stacks/ts-react-tailwind.md` |
| `package.json`, TS, no React | `stacks/ts-node.md` |
| `pyproject.toml` / `setup.py` / `manage.py` | `stacks/python.md` |
| none of the above | skip baseline; rely on repo docs + siblings, note it in the report |

3. For each changed file, **sample its siblings** (other files in the same directory) to learn the local idiom before judging the diff.

---

## Step 3 — Audit each new chunk against the universal axes

For every new symbol or UI piece the diff introduces, search for a precedent before accepting it. Universal axes (the stack file adds concrete recipes):

1. **Reinvented utility** — a new helper/hook/component/type that duplicates an existing one. Grep for verbs (`format`, `parse`, `build`, `get`, `from`, `to`), the entity noun, and sibling files. "I couldn't think of an existing one" is not a clearance — search harder.
2. **Convention drift** — naming, import style (absolute vs relative), file extension/layout, `const` discipline, export style — diverging from neighbours.
3. **Architectural drift** — a state/layer/data-flow choice that differs from how comparable code in the repo does it (e.g. a new state library for one component when the repo has a chosen one).
4. **Styling drift** — raw values instead of the repo's design tokens, a new button/tag variant when one exists, CSS approach that differs from the repo's (utility classes vs modules vs CSS-in-JS).
5. **Design / layout placement drift** — action-button position, header layout, list-row shape, dialog/drawer footer order, empty-state structure, column/field order. Find the closest comparable surface; if placement differs, flag it and **cite the comparable surface (file:line)**.
6. **Naming precision** — names that under-specify (a `Set` of appointment ids named `…PatientIds`). The name should say what it holds.
7. **Sibling parity** — for each non-trivial *behavior* the diff introduces (a permission/edit gate, an enable condition, a close/escape flow, a selection model), name the intent, find siblings facing the same intent, and if they diverge, converge on the better approach — don't default to the nearest neighbour; state the winner and why.

**Confidence ≥ 80%. Cite the canonical version (file:line) for every finding.** Don't flag patterns the repo's docs explicitly sanction (documented hacks, intentional exceptions).

For a large diff, dispatch a general-purpose search subagent per axis (or per directory) to parallelize the grep/read work, then collect findings — but the citations must be real, not assumed.

---

## Step 4 — Triage & present

- **Auto-applicable** (rename, import-path swap, helper swap, token swap) → apply after a one-line summary, commit.
- **Discussable** (replace a new utility with an existing one, change a state layer, restyle) → present one at a time with the canonical reference + a one-line fix proposal.
- **Informational** (near-miss: an existing util almost covers the case) → list at the end, no action.

Format for discussable findings:

```
[U1] path/to/new-file.ext:12
  New formatScheduledDate() duplicates the existing date formatter (utils/date.ts:8, used in 12 places)
  Proposal: drop the new util, call the existing one.
  → go / skip / discuss
```

Wait for the user per finding (or batch: `apply all U2`, `skip all U4`).

---

## Step 5 — Apply approved fixes

For each approved finding: make the minimal edit, then run the repo's own checks (lint/format, types) on the touched files — see the stack file for the commands. Commit one logical change at a time. If a fix breaks a check, roll back that fix only and note it.

---

## Step 6 — Report

```
── Uniformity ──────────────────────────────────────────────
  ✅ Reinvented utilities — 2 fixes applied
  ✅ Convention drift     — 1 rename applied
  ⚠️ Architectural drift  — 1 finding skipped (user: "needs undo/redo")
  ✅ Styling / layout      — 1 footer button-order swap applied
  Commits added: 3
```

Or, if clean: `✅ Clean — no drift detected`.

---

## Rules

- **Never block** — uniformity is a quality gate. If the user disagrees, skip without argument.
- **Cite, don't assert** — every finding references a file:line where the canonical pattern lives.
- **Don't refactor existing code** — only align *new* code with what already exists.
- **Repo docs win** — when a stack baseline disagrees with the repo's `CLAUDE.md`/`AGENTS.md`, follow the repo.
- **Keep the stack files current** — when you learn a repo-specific convention worth reusing, add it to the matching `stacks/*.md` (or the repo's own docs), so the next run knows it.
