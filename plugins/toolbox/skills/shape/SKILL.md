---
name: shape
description: Shape Up entry point for a new or in-flight ticket — classifies it (trivial/medium/large) against checkable criteria, then routes to decompose/rabbit-holes/direct-to-plan as the classification calls for. Use when the user pastes a ticket, mentions a tracker key, says "shape this", "is this worth shaping", "new ticket", "I was assigned", or wants to re-enter shaping mid-build ("stuck on <KEY>", "coming back to the shaping of <KEY>"). Produces and persists a shaping bundle at ${SHAPING_DIR}/<KEY>.md for toolbox:plan to consume. Do NOT use to create a ticket from scratch (defer to an issue-creation skill) or for build-time diagnostics (use toolbox:am-i-stuck).
user-invocable: true
---

# Shape — Shaping entry point

Single entry point for receiving a ticket. Does nothing on its own: routes to the right sub-skill, bridges into building, and re-enters shaping when the user comes back mid-build stuck.

## Principle

Classic Shape Up: seniors shape, the team bets, the team builds.

Reality here: tickets often arrive under-shaped. The job upstream is shaping them retroactively, before building starts.

With AI-first coding, the time appetite no longer reflects complexity — a "1 week" ticket can be 3 hours of real focus with Claude Code. But the cognitive load of the decisions (naming the rabbit holes, splitting the work, prioritizing) is still human. That's what gets shaped here.

## What shaping decides vs. what building decides

- **Shaping (this skill)** decides **what** ships, in **what order**, with **what minimal viable scope**. Produces a markdown bundle.
- **Building (`toolbox:plan` and beyond)** decides **how** to implement it. Consumes the bundle as input.

**Golden rule**: never decide implementation (library, pattern, architecture) during shaping.

**Works from Claude Code, where the real code is reachable.** Use that access to validate scope, never to decide the how:
- Confirm a component/util/endpoint the scope calls for actually exists (reuse vs. build).
- Settle a triage counter-argument (medium vs. large) by reading the code instead of guessing.
- Ground sub-ticket independence in the real code, not an assumption about it.

The line not to cross: reading code to confirm a scope claim is fine. Choosing the architecture, the library, or the pattern is already building — note the question, move on.

## Activation

Triggers automatically when:
- A pasted text block reads like a ticket (title + description) with an ask to scope it
- Phrases: "shape this", "help me scope this", "I was assigned to", "new ticket", "decompose this", "is this worth shaping"
- Re-entry: "I'm stuck on ABC-1234", "this isn't working for ABC-1234", "coming back to the shaping of ABC-1234", "the rabbit hole is bigger than expected"
- `toolbox:start-issue` recommends it (multi-deliverable issue, no parent ticket, no bundle found)

Does not trigger for:
- A bare tracker key or URL with no other instruction — `detect-issue-link.sh` already routes that to `toolbox:start-issue`
- Creating a ticket from scratch — defer to an issue-creation skill
- Questions about a ticket already in flight (debug, code review)

**Input mechanism**: every question to the user goes through `AskUserQuestion`.

## Which flow

Two distinct flows. Which one applies is decided at activation:

| Situation | Flow |
|---|---|
| Ticket pasted / mentioned, not yet shaped | **Main flow** |
| Tracker URL for a ticket never worked on | **Main flow** |
| "new ticket", "I was assigned to" | **Main flow** |
| "I'm stuck on X" | **Re-entry flow** |
| "this isn't working for X" | **Re-entry flow** |
| "coming back to the shaping of X" | **Re-entry flow** |
| "the rabbit hole is bigger than expected" | **Re-entry flow** |

Once a flow is picked, don't switch mid-session without naming it explicitly.

## Main flow — new ticket

### Step 1 — Pull ticket context

Detect the tracker the same way `issues-candidate` and `start-issue` do: check for an already-configured tracker MCP/CLI first — found one, use it, stop there, don't also check the git remote. Only if none is configured, fall back to the git-remote-inferred host. No tracker reachable → work from whatever text was pasted.

Fetch title, description, labels, project, parent, links. Show a 3-line summary, max:
```
Ticket: ABC-1234 — Add activities tab to patient detail view
Project: X | Labels: Y, Z | Parent: ABC-1000
Description (first sentence): [...]
```

### Step 2 — Triage inline

Always run before routing. Classify **trivial / medium / large** in 30-60 seconds against externalized, checkable criteria — not a deep analysis. Nobody should have to feel whether the call is right; each class is a checklist.

**Trivial** — a ticket is trivial if **all** of these are true. One false criterion and it isn't trivial.

Clarity:
- [ ] The "what" is understandable in one read, no reinterpretation needed
- [ ] The "why" is obvious, already known, or unnecessary
- [ ] No phrase like "would need to check", "depends on", "to be defined"

Technical:
- [ ] Familiar technical area (no new lib, no new pattern)
- [ ] 1-3 files estimated touched
- [ ] No new API or new hook to create

Human:
- [ ] No product decision to make
- [ ] No cross-team review needed
- [ ] No alignment needed with another person

Typical AI-first appetite: 1-3h of real focus.

Examples: a bounded visual bug fix (padding, hover state, typo); adding an existing field to an existing modal; a mechanical refactor of a pattern already established elsewhere; a minor lib bump with no breaking change.

Verdict: skip shaping, straight to build.

**Medium** — a ticket is medium if **not all trivial criteria hold** and none of the large signals below are present.

Typical traits:
- [ ] The "what" is clear but the "how" has 2-3 plausible approaches
- [ ] Scope limited to one domain, not cross-feature
- [ ] 1-2 fuzzy zones identifiable quickly
- [ ] No sub-tickets needed, but a few decisions to make
- [ ] 0-2 predictable rabbit holes

Typical AI-first appetite: 3-8h of real focus.

Examples: a new UI feature in an existing flow (new tab, new filter); integrating an endpoint that already exists on the backend; migrating a component to the design system.

Verdict: 0 fuzzy zones → bundle direct. 1-2 fuzzy zones → propose `toolbox:rabbit-holes`.

**Large** — a ticket is large if **at least one** of these signals is present. One is enough.

Size signals:
- [ ] Description lists several distinct deliverables ("add X, Y and Z")
- [ ] A whole new user flow (new page, new wizard)
- [ ] Contains the words "full refactor", "new architecture", "unify", "complete migration"

Coordination signals:
- [ ] Cross-team dependencies (backend + frontend + design all mentioned)
- [ ] Parent ticket / epic explicitly referenced

Ambiguity signals:
- [ ] Vague description with 3+ occurrences of "to be defined", "would need to check"
- [ ] Scope clearly exceeds a day even with Claude Code (> 8h estimated)

Typical AI-first appetite: > 8h of real focus. Can't ship cleanly in one cycle.

Verdict: route to `toolbox:decompose`.

**Triage output** — produce **exactly** this format, criteria checked or not:

```
Triage: [trivial | medium | large]

Criteria checked:
- [x or space] [criterion cited from the ticket]
- [x or space] [criterion cited from the ticket]
- [x or space] [criterion cited from the ticket]
(max 3-4 criteria cited — the most decisive ones)

Why this class:
[1 sentence — the dominant signal that decided it]

Estimated appetite: ~X hours of real focus
Fuzzy zones: [0, 1, 2, or "several"] — name briefly, no detail

Counter-argument:
[1 sentence: under what condition this verdict would be wrong. E.g. "This would be
medium, not trivial, if the backend isn't built yet, which I can't verify from here."]

Next step:
[per the routing table below]
```

The counter-argument section is **mandatory**. It externalizes the doubt so the verdict's fragility is visible without needing intuition to spot it. Keep the whole triage output compact — never exceed 15 lines total.

Never ask the user a clarifying question before delivering the verdict. Triage runs on the ticket as it stands — if something is genuinely unclear, that unclarity is itself the signal; it goes in the counter-argument, not in a question asked first.

In Claude Code, if the counter-argument is checkable in the code (e.g. "this would be medium if component X already exists"), settle it by reading the code before routing — don't route on a guess a `grep` could confirm.

**Edge cases**:
- **Ambiguous between two classes** → always round up (medium over trivial, large over medium). Rationale: asymmetric error cost — an unnecessary shaping pass costs 15 minutes, a missed one costs hours of an unseen rabbit hole.
- **Genuinely vague ticket (title only, no description)** → classify large by default. In "Why this class": "Description insufficient to judge. Decompose's first job is clarifying with the author."
- **Urgent / P0 ticket** → the class doesn't change. In "Next step", note the urgency separately: "Urgent — you can choose to skip shaping even at medium, but the concrete risk is: [risk]."
- **Ticket that looks trivial but has 1 fuzzy zone** → it's medium, not trivial. One fuzzy zone alone is enough to leave trivial. Strict rule.

When torn between two classes after checking the criteria, the doubt itself is the signal that information is missing — surface it in the counter-argument and let the user decide with context only they have.

**Routing**:

| Class | Fuzzy zones | Next |
|---|---|---|
| Trivial | any | Skip straight to `toolbox:plan` |
| Medium | 0 | Bundle direct |
| Medium | 1-2 | `toolbox:rabbit-holes` |
| Large | any | `toolbox:decompose` |

Never launch more than one downstream skill at a time. Wait for its output, propose the next step, the user decides.

Trivial routes out of this flow entirely — no time-box check-in, no bundle. Steps 3-5 below apply only when routing continues past triage (medium or large).

### Step 3 — Time-box and focus check-in

No passive timer. Estimate elapsed time only when producing a response, from: how many messages have been exchanged, how substantial each exchange was, the first message's timestamp if available.

Time thresholds — weave into the normal flow of the response, don't interrupt with them:

~15 min elapsed, no check-in done yet:
> "About 15 minutes into shaping. Where we are: [short recap of decisions made]. Keep going on this, or close with the current bundle?"

~30 min elapsed, one check-in already done:
> "Approaching 30 minutes. [Recap]. Two options: (a) close here with the current bundle, (b) 15 more minutes on [what's left]. Which one?"

~45 min elapsed:
> "About 45 minutes in. That's a lot for a medium ticket, and the high end of the range for a large one. Possible signal of over-shaping or an under-specified ticket. Recommend closing with what we have."

Focus-drift signals — name these explicitly when they show up:

**Horizontal** (3+ distinct tickets opened in the same session):
> "We've opened ABC-1111, ABC-2222 and ABC-3333 — which one closes before the next opens? My pick: [the most advanced one]."

**Vertical** (5+ sub-tickets produced, or a cascade of sub-decisions in under 2 hours):
> "We're at [N] sub-tickets / [M] technical sub-decisions. Signal of a vertical dive. Check: does every sub-ticket have a distinct user-facing deliverable? If not, merge them."

**Tooling-shopping** (discussing libraries, patterns, architecture mid-shaping): that belongs to building. Reading code to validate a scope claim stays fine; choosing the tool or pattern doesn't — note the question in the bundle, move on.

If pushed back on, hold the line. Offer an explicit MVP: "ship the first two sub-tickets, reassess the rest after."

### Step 4 — Produce and persist the bundle

Write the bundle once the classification and routing are decided — not only at the very end of the session. For medium + 0 fuzzy zones, that's the final bundle. For medium + 1-2 fuzzy zones or large, write it now, before the routed skill runs, with what's known so far (classification, scope) and no `## Sub-tickets` / `## Rabbit holes` section yet — `toolbox:decompose` and `toolbox:rabbit-holes` are themselves bundle writers (per the shared contract below) and fill in their own section on the same file when they return. Either way, persist it so `toolbox:plan` (building) and `toolbox:retrospect` (later) can find it.

Resolve the ticket id — the key already known wins, in this order:
- **Known ticket key** (fetched from the tracker in Step 1, or present in the pasted ticket text) → use it directly as `TICKET_ID`.
- **No key in hand, but a branch already exists** (re-entry flow, mid-build) → parse it from the branch, secondary source only:
  ```bash
  TICKET_ID=$(git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]')
  ```
- **No ticket key anywhere** → derive a short slug from the ticket title instead, same fallback `plan` uses for a raw description.

**Bundle format** — the shared contract `plan`, `context-validator` and `retrospect` all read. Don't improvise fields:

```markdown
---
ticket_id: <KEY or slug>
created_at: <ISO 8601>
classification: [trivial | medium | large]
status: shaped
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
```

Frontmatter fields:
- `ticket_id` — the resolved key or slug
- `created_at` — ISO timestamp at creation
- `classification` — the triage verdict
- `status` — `shaped` at creation; later moves to `in_progress` (`plan` ingests it), `shipped` (`retrospect`), or `reshaped` (re-entry flow, below)

**Check for an existing bundle first** (same lookup `toolbox:plan` uses to find one):
```bash
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```
Found one → never silently overwrite. Ask:
> "A bundle already exists for <KEY> (status: [X], created [date]). Options: (a) overwrite, (b) append under a new header, (c) cancel."

**Persist**:
```bash
[ -n "$SHAPING_DIR" ] && mkdir -p "$SHAPING_DIR"
# write the bundle to ${SHAPING_DIR}/<TICKET_ID>.md (or ${SHAPING_DIR}/<slug>.md)
```
`SHAPING_DIR` unset → persistence isn't available. Say so, present the bundle in chat only, don't hard-fail.

After writing, show the bundle in a markdown code block plus the file path:
> "Bundle written to `${SHAPING_DIR}/<KEY>.md`. `toolbox:plan` picks it up automatically from the branch, or reads it directly if pointed at the ticket id."

Shaping happened directly in Claude Code → no copy-paste or ingestion step needed. Chain straight into whatever was routed to (`rabbit-holes`/`decompose`) if anything ran, then `toolbox:plan`.

### Step 5 — Propose retrospect after ship

The bundle file is the persistent trace. Until its `status` is `shipped`, a retrospect is still owed — scannable at any time with `grep -l "status: in_progress" "$SHAPING_DIR"/*.md`.

When the user reports a ticket shipped / merged / in review, propose:
> "<KEY> is shipped. Want a quick retrospect (5 min) to calibrate the shaping? `toolbox:retrospect` reads the bundle at `${SHAPING_DIR}/<KEY>.md` and compares it against what actually happened."

If declined, don't push — but propose it every time. It's the only review mechanism this flow has.

## Re-entry flow — stuck or coming back to reshape

### Step 1 — Acknowledge, no judgment

One sentence, max:
> "OK, re-shaping. This usually means a rabbit hole nobody saw on the first pass, not a planning failure."

No reassurance monologue. Name that it's normal, then move to action.

### Step 2 — Diagnose via `toolbox:am-i-stuck`

Don't re-derive the diagnostic here — `toolbox:am-i-stuck` already owns it (hill-chart position, time invested, internal signal, scope check) and produces exactly one recommended action. Run it.

### Step 3 — Act on the recommendation

Recommendation is anything other than reshape (continue, downscope, pause, ask for help) → hand it back. That's a build-time action, not a shaping one; `shape` has nothing to add.

Recommendation is **reshape** → re-enter shaping and append a `## Reshape` section to the existing bundle. Never replace the original shaping — the reshape complements it.

**File handling** — never overwrite, always append. Check first, same lookup as the main flow's Step 4:
```bash
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```
- Bundle exists for this id → update the frontmatter to `status: reshaped`, append the reshape under a new `## Reshape — <ISO timestamp>` header at the end of the file.
- No bundle exists → create one with full frontmatter (classification estimated or re-asked), then write the reshape section directly.

**Reshape section format** (from the bundle contract above):
```markdown
## Reshape — <ISO timestamp>
**Blocker**: [1-2 sentences]
**Time invested before reshape**: [X hours]
**What changes**: [reshape decisions, with rationale for each]
**Still valid from the initial shaping**: [short list — don't discard prior work]
**New first step**: [concrete sentence]
**For retrospect**: [1-2 sentences — what this reshape says about the initial shaping]
```

Persist with the same `${SHAPING_DIR}` pattern as the main flow's Step 4 (`SHAPING_DIR` unset → present in chat only, say so).

Present to the user:
> "Reshape written to `${SHAPING_DIR}/<KEY>.md` (status: reshaped). The file now holds the initial shaping plus this reshape. `toolbox:plan` reads both sections."

## Never do

- Never produce code, pseudo-code, or signatures.
- Never decide the technical architecture.
- Never create sub-tickets directly — that's always `toolbox:decompose`'s job, which delegates to an installed issue-creation skill or a tracker's own create step.
- Never close on pep talk.
- Never produce an output without an explicit rationale. Every decision carries a "because [X]".

## Output format

- No emojis
- No decorative bullets — lists only when structural
- Final bundle in a markdown code block
- Rationale on every decision: decision + "because [X]"
