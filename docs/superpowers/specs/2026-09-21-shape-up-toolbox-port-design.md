# Shape Up shaping flow → toolbox port

Status: approved, pending implementation

## Problem

`toolbox:plan` and `toolbox:context-validator` already read `${SHAPING_DIR}/<TICKET>.md`
(`PROFILE.example.md` documents the field) expecting a persisted shaping bundle with
scope/reshape sections. Nothing in the toolbox produces that file. The producer exists
only as six Gray-coupled skills in `~/.claude/skills/` (`ticket-shape`, `ticket-triage`,
`ticket-decompose`, `ticket-rabbit-holes`, `ticket-retrospect`, `ticket-unbundle`), tied to
Linear MCP, French copy, `GRA-XXXX` ticket keys, and Gray-specific persistence paths.

Goal: port a generic, instance-agnostic version into `plugins/toolbox/skills/`, filling the
dangling `SHAPING_DIR` reference, without 1:1-copying every Gray skill.

## Non-goals

- Not porting `ticket-unbundle` — `toolbox:plan` Step 0 already finds and ingests the
  persisted bundle at session start. A second ingestion skill would duplicate that step.
- Not porting `linear-issue-creator` — `toolbox:start-issue` already has the pattern
  (defer to an environment-installed issue-creation skill if present, else follow a
  generic standard) and `toolbox:issues-candidate` already ships tracker create-calls
  (`trackers/<host>.md`) to reuse for sub-ticket creation.
- Not reimplementing the Gray "blocked mid-build" flow — `toolbox:am-i-stuck` already
  covers that diagnostic. The new orchestrator points at it instead of duplicating it.
- No new `PROFILE.md` fields. `SHAPING_DIR`, `TICKET_PREFIX`, `TRACKER` already exist.

## Consolidation

6 Gray skills → 4 toolbox skills:

| Gray original | Toolbox home |
|---|---|
| `ticket-shape` (orchestrator) | `toolbox:shape` |
| `ticket-triage` | folded into `toolbox:shape`, inline (30-60s check, not worth a separate invocable skill) |
| `ticket-decompose` | `toolbox:decompose` |
| `ticket-rabbit-holes` | `toolbox:rabbit-holes` |
| `ticket-retrospect` | `toolbox:retrospect` |
| `ticket-unbundle` | dropped — redundant with `toolbox:plan` Step 0 |
| `linear-issue-creator` | dropped — redundant with `start-issue`'s delegation pattern + `issues-candidate`'s tracker adapters |

## Bundle contract (shared — `shape`, `decompose`, `rabbit-holes` write it; `plan`,
`context-validator`, `retrospect` read it)

Path: `${SHAPING_DIR}/<TICKET_ID>.md`. No tracker ticket yet → slug fallback
(`${SHAPING_DIR}/<slug>.md`), same pattern `plan`'s raw-description fallback already uses.

```markdown
---
ticket_id: <KEY or slug>
created_at: <ISO 8601>
classification: [trivial | medium | large]
status: shaped   # shaped -> in_progress (plan ingests) -> shipped (retrospect) | reshaped
---

## Ticket: <KEY> — <title>

## Classification
- Class: [trivial | medium | large]
- Why: [one line — the deciding signal]

## Scope
**Shipping**: [2-3 sentences]
**Why this scope**: [1 sentence — concrete problem solved]
**Not shipping**: [short list, one reason each]

## Code reality verified
[Only present if shaped in Claude Code: components/utils/endpoints confirmed to exist
(reuse vs build), triage counter-arguments settled by reading code. Omit section if not
shaped in Code.]

## Sub-tickets
[Only if decompose ran. Ship order, one line why each sub-ticket is at its position.]

## Rabbit holes
[Only if rabbit-holes ran. RH-N: title — decision (treat/ignore/downscope/spike) —
rationale — early signal to watch. If not run: "No rabbit-holes pass. Watch for it during
build."]

## First step
[One sentence: exactly where to start when building begins.]

## Discarded context
[Optional. Paths considered and rejected, with why — for future-you re-litigating.]

## Reshape — <ISO timestamp>
[Appended, never overwrites, when `shape` re-enters mid-build via a "stuck" re-entry that
escalates past what am-i-stuck's diagnostic alone resolves. Contains: blocker summary, time
invested before reshape, what changes, what's still valid from the initial shaping, new
first step, one line for retrospect's benefit.]
```

`context-validator` already reads `## Scope` for ship/don't-ship and honors a `## Reshape`
section as the newer source of truth — this format matches that expectation as-is.

## toolbox:shape

Orchestrator + triage inlined. Two entry flows:

**New ticket** (or pasted idea / raw description):
1. Pull ticket context (tracker MCP/CLI if a key/URL is given, else work from what's
   pasted) — same tracker-detection order as `issues-candidate` (configured MCP/CLI first,
   git remote only as fallback).
2. Triage inline: classify trivial/medium/large against externalized, checkable criteria
   (ported near-verbatim from `ticket-triage` — the criteria are already generic). Output
   is short: class, 2-4 cited criteria, why, appetite estimate, fuzzy-zone count, a
   mandatory one-line counter-argument, next step.
3. Route: trivial → skip straight to `toolbox:plan`. medium + 0 fuzzy zones → bundle
   direct. medium + 1-2 fuzzy zones → `toolbox:rabbit-holes`. large → `toolbox:decompose`.
   Never launch more than one downstream skill at a time; wait for its output, the user
   decides the next step.
4. Time-box / focus check-in, genericized (no AuDHD framing — a plain anti-scope-creep
   pattern for the shaping session itself, distinct from `am-i-stuck` which only covers
   build sessions): flag 3+ distinct tickets opened in one shaping session ("which closes
   before the next opens"); flag ~15/30/45 min elapsed in one shaping session with a
   check-in or close-with-current-bundle prompt.
5. Golden rule carried over unchanged: never decide implementation (lib/pattern/architecture)
   during shaping. In Claude Code, reading code to confirm a scope claim (does this
   component/endpoint exist) is fine; choosing the approach is not — note the question,
   move on.
6. Write the bundle (format above) to `${SHAPING_DIR}/<TICKET_ID>.md`. Existing file for
   that id → do not silently overwrite; ask overwrite / append-new-section / cancel.
7. Once the user reports a ticket shipped, proactively propose `toolbox:retrospect` (this
   is the only review mechanism the flow has — propose every time, don't insist if declined).

**Re-entry ("stuck", "back to shaping for X")**: one line acknowledging it's normal, then
point at `toolbox:am-i-stuck` for the diagnostic. If that diagnostic's recommended action is
"reshape," `shape` re-enters, appends a `## Reshape` section to the existing bundle (never
overwrites the original), and proposes the new first step.

## toolbox:decompose

Near 1:1 port of `ticket-decompose` — the mechanics (read ticket → detect distinct
deliverables/fuzzy zones/dependencies → propose 2-5 sub-tickets, each independently
shippable, with a verifiable quality bar per sub-ticket → ship order with one-line
rationale each) are already generic. Delta: sub-ticket creation delegates to *(a)* an
environment-installed issue-creation skill if present, else *(b)* `issues-candidate`'s
`trackers/<host>.md` **Create** step, adding parent/`blockedBy` fields for sequencing. No
new tracker adapter files — reuse the existing ones.

## toolbox:rabbit-holes

Near 1:1 port of `ticket-rabbit-holes` — fixed 4-dimension grid (technical, data, user
flow, human/coordination), each rabbit hole must name a concrete trigger signal and an
estimable cost or it doesn't count. Delta: drop the RO/MO-specific line in the user-flow
dimension; keep the grid otherwise unchanged.

## toolbox:retrospect

Near 1:1 port of `ticket-retrospect` — reads the persisted bundle the same way `plan`
does (`${SHAPING_DIR}/<TICKET_ID>.md`), asks exactly 3 fixed questions comparing shaped vs.
actual (rabbit holes hit vs. predicted, scope held vs. drifted, classification accurate in
hindsight), produces a short gap summary + 1-2 adjustments for next time. Stays distinct
from `what-did-we-learn` (that skill explicitly scopes itself to generalizable-knowledge
capture, not estimate calibration) — different trigger, different questions, no overlap.

## toolbox:start-issue touch-up

`start-issue` Step 4 (simple/complex build-triage) doesn't know shaping bundles exist —
`toolbox:plan` already checks `SHAPING_DIR`, `start-issue` doesn't, so the two entry points
can disagree. Add a bundle check at the top of Step 4, before the existing simple/complex
heuristic:

```bash
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```

- **Bundle found**: use its `classification` instead of re-deriving simple/complex.
  `trivial`/`medium` → fall through to the existing simple/complex criteria as today.
  `large` → this issue is expected to already be one of `decompose`'s sub-tickets (created
  with a parent link) — plan it directly. If it has no parent link despite being marked
  `large`, say so; decomposition may not have happened yet.
- **No bundle**: today's heuristic is unchanged, but the "Complex" criteria list gains one
  line — multiple distinct deliverables in the issue body and no parent ticket → recommend
  `toolbox:shape` before planning, rather than silently planning a ticket that should have
  been decomposed first.

Rest of `start-issue` (branch/worktree, state transitions, build, ship, report) is
untouched.

## Testing / verification

Markdown-only skills, no build. Verification is manual dry-run: walk `toolbox:shape`
through a fake ticket end-to-end (trivial path, medium+rabbit-holes path, large+decompose
path), confirm the bundle it writes parses correctly as input to a `toolbox:plan` dry run,
and confirm `toolbox:context-validator` reads the `## Scope` section correctly against it.
Also confirm `start-issue`'s Step 4 bundle check picks up a `large`-classified bundle and
skips its own heuristic, and that the no-bundle path still recommends `shape` for a
multi-deliverable issue.
