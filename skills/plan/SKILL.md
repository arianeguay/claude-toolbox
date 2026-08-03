---
name: plan
description: Produce an implementation plan anchored in the real code — the missing bridge between shaping (decisions/rationales/rabbit holes) and the build. Use just before writing code, when the user says "make me a plan", "plan for <TICKET>", "let's plan before coding", "before we start", or after a shaping/unbundle step when the context is ready but a concrete plan is missing. Consumes existing shaping context when present, otherwise takes a ticket id or a raw description and reads the code itself. Outputs an ordered list of changes with the files each one touches, persisted to `.plans/<TICKET>.md`. Do NOT use for shaping or for deciding scope — this decides the HOW, not the WHAT.
user-invocable: true
---

# Plan — Shaping → Build bridge

The last link before writing code. Shaping decides **what** to ship and in **what order**; this skill decides **how**, anchored in the real code.

**Principle:** a shaping bundle gives decisions and their rationales, but not an implementation plan validated against the codebase. This skill fills that gap — it reads the real code to confirm what already exists (reuse vs build), where the change plugs in, which pattern to follow, then outputs an ordered list of changes.

**What this skill is NOT:** not heavy phases with a verification criterion per step. An ordered list, each item naming the files it touches. Consistent with `toolbox:smallest-footprint`: the lightest plan that lets you code without re-guessing.

## Step 0 — Detect the entry path

Auto-detect. Don't make the user choose.

**Option A — shaping context already present (main path):** the ticket's decisions, rationales and rabbit holes are already in the conversation (an unbundle step ran this session, or the user pasted/summarised the shaping). Reuse them as-is — don't re-ask, don't re-read the bundle from disk when the context is already there.

If nothing is in context, look for a persisted bundle before falling back. Extract the ticket id:
```bash
# TICKET_PREFIX and SHAPING_DIR come from PROFILE.md
TICKET_ID=$(git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]')
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```
File found → ingest it as Option A context.

**Fallback — no shaping context:** covers trivial tickets that skip shaping. Take whatever input is available:
- A ticket id (from the branch or the message) → read the ticket from the tracker for its title and description.
- A pasted raw description → work from that.

The fallback reads the code itself without the benefit of shaping rationales. Don't re-shape (no scope splitting, no rabbit holes) — just plan the how of the work as described.

Name the path taken in one line: `Path: Option A (shaping context)` or `Path: fallback (trivial ticket)`.

## Step 1 — Anchor the plan in the code

This is the value of the skill — don't skip it. Before writing a single line of the plan, read the real code to validate every implementation assumption:

- **Reuse vs build:** does the component/util/hook/endpoint you need already exist? Grep before assuming you have to create it. Reuse beats reinvention — `toolbox:uniformity-check` would flag it otherwise.
- **Insertion point:** where does the change plug in? Read the target file, find the exact function/component and the neighbouring pattern to follow.
- **Implicit coupling:** is there a twin to keep in sync (two functions that mirror each other, i18n across every locale, a selector that has to re-project into scope)?
- **Contradicts the shaping?** If the code contradicts a decision from the bundle (an assumed pattern doesn't exist, an endpoint is missing), name it explicitly — this is the one case where you go back to shaping. Don't silently patch around it.

Every plan item must trace to code you read, not code you guessed. If an assumption couldn't be verified, mark it `(unverified)` rather than asserting it.

## Step 2 — Produce the plan

Ordered list. Each item: what changes, the file(s), and a reuse-vs-new note where relevant. Keep it light.

```markdown
# Plan — <TICKET>: [title]

Path: [Option A (shaping context) | fallback (trivial)]
Scope: [one sentence — what ships]

## Changes

1. [Concrete action] — `path/file.tsx`
   [1 clause of context if non-obvious: reuses `X`, follows the `Y` pattern, or new]
2. [Action] — `path/other.ts`
3. ...

## Anchoring notes
- Reused: [existing utils/components found]
- New: [what doesn't exist and must be created]
- Unverified / assumptions: [or "none"]
- i18n: [keys to add across locales, or "none"]
```

No per-step verification criteria, no named phases. The order of the items **is** the build thread. Group changes the way they'll be committed (one item ≈ one logical commit where it falls out that way).

Stay inside the shaped scope. Don't add "while we're in there" items — every line traces to what was asked.

## Step 3 — Persist

Write the plan to disk at the worktree root:
```bash
mkdir -p .plans
# write to .plans/${TICKET_ID}.md
```
No ticket id (raw-description fallback) → use a short slug: `.plans/<slug>.md`.

Survives the session, and a retrospective can find it to compare plan vs reality.

## Step 4 — Move to the build

The plan is the build guide. Show the user the plan, then execute it top to bottom: code each item, commit per logical change, lint + type-check + tests along the way — autonomously, without asking permission.

If an item turns out to be wrong mid-build (the code doesn't match the plan), fix the plan alongside the code — don't let `.plans/<TICKET>.md` drift from reality.
