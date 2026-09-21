---
name: retrospect
description: Quick post-ship review (5-10 min max) of a shipped ticket to calibrate shaping accuracy — asks exactly 3 fixed questions comparing shaped vs. actual (rabbit holes, scope drift, classification accuracy), writes a structured gap summary plus at most 1 adjustment to the bundle, and logs a data point to the aggregate calibration log. Use after the user says a ticket shipped/merged/is in review, or asks for "a retrospect on <KEY>". Never use mid-build (see toolbox:am-i-stuck) or on an abandoned ticket. Distinct from toolbox:what-did-we-learn, which captures generalizable knowledge, not estimate calibration.
user-invocable: true
---

# Retrospect — post-ship shaping calibration

Quick review (5-10 min max) of a shipped ticket, to calibrate estimates and capture what was learned.

**Principle**: without a feedback loop, shaping never improves. That loop needs to be external and systematic — not dependent on memory or gut feel — for the calibration to hold up over time. This calibrates shaping *quality* (classification accurate, rabbit holes anticipated, scope held), not execution time.

**This skill is one of two review mechanisms in the flow** (the other is `toolbox:am-i-stuck`, which is in-flight). Without it, no calibration happens at all.

## When to use

- Called by `toolbox:shape` when the user mentions a ticket is shipped/merged/closed
- Invoked directly: "retrospect on <KEY>", "let's do a retro on <KEY>"
- **After** the ticket is done. Never mid-build.
- **Before memory fades**: within 2-3 days of shipping ideally, not two weeks later.

Not for:
- A ticket still in flight (that's `toolbox:am-i-stuck`)
- An abandoned ticket (no usable data)
- A whole-sprint retrospective (different exercise, out of scope)

## Flow

### Step 1 — Fetch context

**Look for the persisted bundle first**, the same lookup `toolbox:plan` Step 0 already uses:

```bash
TICKET_ID=$(git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]')
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```

No match from the branch → use the id/slug the user named when invoking this skill (e.g. "retrospect on ABC-1234"). Neither present → ask which ticket this retrospect is for.

- **Bundle found**: its content is the source of truth for the initial shaping — classification, predicted rabbit holes, sub-tickets, shaped scope. Extract these from the frontmatter and body before Step 2.
- **Bundle not found**: ask the user to recall the initial shaping. Don't force it if they don't remember — work with what's there. Note in the final recap that there was no persisted bundle — that's itself a process signal (shape more tickets).
- **`SHAPING_DIR` unset**: persistence isn't available. Same as above — work from what the user remembers, note it.

**Supplementary tracker read**, same detection order `issues-candidate`/`start-issue` use: a configured tracker MCP/CLI first; else the git-remote-inferred host; else work from pasted text with no tracker reachable. Pull, if available:
- Final status (done / released / closed)
- Created vs. closed date, for a rough sense of calendar time
- Comments about blockers

### Step 2 — Collect the gaps (3 targeted questions)

Ask **exactly 3 questions**, in one `AskUserQuestion` call — no more, no fewer, and not spread across separate turns:

**Question 1 — Rabbit holes**

> "Of the rabbit holes identified at shaping, what happened?"
> Options:
> - "All anticipated, no surprise"
> - "One unseen rabbit hole showed up"
> - "Several unseen rabbit holes"
> - "Some predicted rabbit holes turned out irrelevant"
> - "No rabbit-holes pass was done"

**Question 2 — Scope**

> "Did scope move during the build?"
> Options:
> - "No, stable"
> - "Downscoped along the way (removed things)"
> - "Scope crept (added things)"
> - "Full reshape mid-build"

**Question 3 — Classification (triage)**

> "Did the triage classification (trivial / medium / large) match the reality of the build?"
> Options:
> - "On target"
> - "Bigger than classified"
> - "Smaller than classified"
> - "No triage at shaping"

### Step 3 — Analyze the gaps

Based on the 3 answers, produce a structured analysis. Rules:

**If classification off (bigger / smaller than classified)**: find the cause yourself, no extra question needed.
- Bigger → an unseen rabbit hole or fuzzy zone blew up the real scope. Note it to improve `toolbox:shape`'s triage or `toolbox:rabbit-holes`.
- Smaller → over-classification — the triage grid over-reacted to a signal. Note the ticket type to recalibrate.
- Recurring pattern on a ticket type → name it explicitly.

**If an unseen rabbit hole showed up**, ask one follow-up question:
> "Did that rabbit hole fit one of the 4 dimensions (technical / data / user flow / human) that `toolbox:rabbit-holes` should have scanned? If so, which one?"

That answer is what feeds the retrospect with actionable signal.

**If scope moved**, ask one follow-up question on direction and reason:
> "Which direction did scope move? (a) the initial scope turned out incomplete, (b) non-critical things got added while in flow, (c) a change came from outside."

If (b): that's a scope-creep-while-in-flow pattern worth documenting — explicit, checkable signals here beat trying to judge in the moment whether the extra work was warranted, for anyone shaping solo.

### Step 4 — Produce the summary

Strict format:

```
Retrospect: <TICKET_ID> — [title]

Gaps observed:
- Classification: [on target / bigger than classified / smaller than classified / no triage]
- Rabbit holes: [N predicted, M seen, K unseen]
- Scope: [stable / downscoped / crept / reshaped]

Dominant cause of the gap (if any):
[1 sentence naming the main pattern]

Learning (1-2 sentences max):
[What this ticket teaches for the next ones. Concrete and actionable, not philosophical.]

Pattern to watch for the next similar ticket:
[If the gap reveals a recurring pattern, name it explicitly.
Example: "Tickets touching the worklist are consistently under-classified at
triage — pattern observed across 3 tickets now."]

Proposed adjustment to the flow:
[At most 1 concrete adjustment. E.g.: "In toolbox:rabbit-holes, add a systematic
question about timezones for tickets touching X." or "No adjustment, this was
within normal margins."]
```

"Pattern to watch" is the critical line — it's the only place in the flow where cross-ticket patterns get captured.

### Step 5 — Offer to persist the pattern

Only if the retrospect revealed a **strong pattern** — repeated across 2+ prior tickets, or clearly robust on its own. A single first occurrence doesn't qualify; skip this step entirely (nothing offered, nothing written) and let the pattern live only in this retrospect's summary and log row.

If it does qualify:
- If this session exposes some persistent memory/preference mechanism, offer to use it:
  > "This pattern [X] looks solid. Want me to add it to persistent memory so it's in play by default for the next shaping sessions?"
  Confirm first, same gating as everything else in this step. If confirmed, use that mechanism the way it's normally invoked in this session — check first that a similar line doesn't already exist, and reconcile instead of duplicating.
- If declined, or if no persistent memory mechanism is available in this session: write the pattern into the persisted bundle instead, under a `## Patterns observed` section appended at the end of the file (create the section if it doesn't exist yet). Bundle-only, reference for future retrospects — not a global default change.

**Never invoke a memory/preference tool that isn't confirmed to exist in this session.** Don't assume one is available, and never persist a behavior change without explicit confirmation.

### Step 6 — Auto-write the calibration log (no confirmation)

**Always** write a structured data point to the aggregate calibration log, without asking. It's raw data capture, not a behavior change — confirmation only applies to Step 5 (persisting a pattern to preferences).

File: `${SHAPING_DIR}/_calibration_log.md`

If it doesn't exist, create it with this header:

```markdown
# Calibration Log

Aggregate data points from ticket retrospects. One row per shipped ticket.
Used to detect cross-ticket patterns that a single retrospect can't see.

| Date | Ticket | Estimated classification | Actual | Rabbit holes (predicted / seen / missed) | Scope | Dominant cause |
|------|--------|---------------------------|--------|-------------------------------------------|-------|-----------------|
```

Append a row matching the 3 answers plus the analysis. Strict format — one line, no line breaks inside cells:

```
| 2026-04-29 | ABC-1234 | medium | bigger | 2 / 3 / 1 | crept | unseen rabbit hole (timezones) |
```

Conventions:
- **Date**: ISO `YYYY-MM-DD` of the retrospect (not the ship date)
- **Estimated classification**: trivial / medium / large (from the bundle if present, else "?")
- **Actual**: on target / bigger / smaller / no triage
- **Rabbit holes**: three integers separated by ` / `
- **Scope**: stable / downscoped / crept / reshaped
- **Dominant cause**: one short phrase (max 60 chars), same value produced in Step 4

`SHAPING_DIR` unset → persistence isn't available. Say so, show the row in chat only, don't hard-fail.

**Why no confirmation**: the aggregate log is what makes cross-ticket patterns visible. Asking for confirmation on every retrospect would kill the externalization. The only gate stays Step 5 (changing default behavior via persistent preferences).

### Step 7 — Update the bundle file

Regardless of Step 5's outcome, update the persisted bundle `${SHAPING_DIR}/<TICKET_ID>.md`:

1. Frontmatter: `status: in_progress` (or `reshaped`) → `status: shipped`
2. Append a `## Retrospect — [ISO timestamp]` section at the end of the file, containing the Step 4 summary. Touch nothing else in the file.

Section structure:

```markdown
## Retrospect — [ISO timestamp]

### Gaps observed
- Classification: [on target / bigger than classified / smaller than classified / no triage]
- Rabbit holes: [N predicted, M seen, K unseen]
- Scope: [stable / downscoped / crept / reshaped]

### Dominant cause
[1 sentence]

### Learning
[1-2 sentences]

### Pattern to watch
[if any]

### Proposed adjustment to the flow
[0 or 1 adjustment]

### Persisted to memory
[Yes, added: "..." | No, noted in the bundle's Patterns observed section | N/A — no pattern strong enough to consider this retrospect]
```

`SHAPING_DIR` unset → present the section in chat only, say persistence isn't available, don't hard-fail.

This trace accumulates in the bundle file — grepping `## Retrospect` across `${SHAPING_DIR}` surfaces every retrospect done, useful for spotting cross-ticket patterns later.

## Strict rules

**10-minute hard cap.** Past that, it's a sign this is turning into a sprint retrospective, not a ticket one. Close it out.

**No judgment on the person.** If classification was off or scope drifted, that's never "you classified this wrong" or "you planned this badly." It's "shaping had this gap, here's how to correct it for next time." Focus is on the **process**, not the performance.

**At most 1 adjustment proposed per retrospect.** No shopping list of improvements. One adjustment at a time, or the ability to tell what worked gets lost.

## Output format

- No emojis
- Fixed structure, no creative variation
- Don't open a sentence with the user's name
- No pep talk, no "nice work shipping this"
- Factual, short, actionable

## Never do

- Never run a retrospect without the 3 questions (it degenerates into open discussion)
- Never propose more than one adjustment
- Never judge the person — judge the process
- Never propose a retrospect on an abandoned or in-flight ticket
- Never exceed 10 minutes
- Never turn this into a "plan the next sprint" session — that's a different exercise
- Never persist a pattern to a memory/preference mechanism without explicit confirmation
