---
name: rabbit-holes
description: Scan a ticket for technical/data/user-flow/coordination rabbit holes using a fixed 4-dimension grid, and produce an explicit treat/ignore/downscope/spike decision for each one that passes a concrete-signal-plus-estimable-cost reality test. Use after toolbox:shape classifies medium with 1-2 fuzzy zones, after toolbox:decompose on the first sub-ticket to ship, or when the user asks "what could go wrong here". Never use on a trivial ticket or for live debugging (the pitfall is already visible by then).
user-invocable: true
---

# Rabbit Holes — systematic risk scan

Scan a ticket for rabbit holes with a **systematic grid** instead of free-form intuition. Turn unknowns into documented decisions.

**Principle**: a real rabbit hole has two criteria. (1) A concrete signal that will give it away. (2) An estimable cost. Without both, it's anxiety, not a rabbit hole.

## When to use

- After `toolbox:shape` classifies medium with 1-2 fuzzy zones
- After `toolbox:decompose`, on the first sub-ticket to ship
- When the user asks "what could go wrong here"
- **Never** on a trivial ticket (negative ROI)
- **Never** in debug mode (the pitfall is already visible)

## Flow

### Step 1 — Targeted read

Pull the ticket plus the relevant code if reachable (MCP, description).

Work through the **4 fixed dimensions** systematically — no free-form order:

**Dimension A — Technical**
Questions to ask:
- New or unfamiliar libs / frameworks / patterns in the codebase?
- Dependencies on external systems (third-party APIs, a backend still in dev)?
- Interactions with fragile legacy code?
- Perf constraints (long lists, frequent refresh, real-time)?
- Browser / device / accessibility compatibility?

**Dimension B — Data**
Questions:
- Shape edge cases (null, undefined, empty array, 1 item, N items)?
- Migrations / transformations of existing data?
- State shared with other features?
- Timezones / dates / localized formats?
- Permissions and conditional visibility?

**Dimension C — User flow**
Questions:
- Intermediate states (loading, error, empty, partial)?
- Undo, cancellation, concurrent edits?
- Interactions with other existing features?
- The "user quits halfway through" case?

**Dimension D — Human**
Questions:
- Unmade product decisions ("UX to confirm", "copy TBD")?
- Cross-team reviews needed (design, backend, QA)?
- Alignment needed with a specific person?
- Undocumented tribal knowledge?

**Answer explicitly for every dimension**: "nothing detected" or list what you see. Never skip a dimension silently.

### Step 2 — List rabbit holes with reality-test criteria

For each rabbit hole identified, apply the **reality test**:

```
RH-N: [short title, 1 line]

Dimension: [A/B/C/D]

Reality test (both must be checked):
- [✓ or ✗] Concrete signal: [describe how this rabbit hole will show itself]
- [✓ or ✗] Estimable cost: [X hours lost | blocks the ship | produces a subtle bug]

If either criterion is ✗: this isn't a rabbit hole, it's anxiety. Drop it.

Likelihood: [high / medium / low]
Based on: [short reason — known patterns, prior experience, nature of the zone]
```

**Hard limit: 5 rabbit holes max per pass.**

More than 5 → signal that the ticket should be re-decomposed via `toolbox:decompose`, or the scope is too ambitious. Name that signal explicitly:

> "Found [N>5] potential rabbit holes. Threshold exceeded. Two hypotheses: (a) the ticket is mis-scoped and should be re-decomposed, (b) this is over-analysis. Which is more likely?"

### Step 3 — Decide for each

For each rabbit hole that passed the reality test, propose one of 4 decisions, with rationale:

**TREAT**: resolve upfront, before the ship starts.
When: high likelihood + high cost. "Treat" means a concrete action before brainstorming starts (read the code, check the docs, ask someone a question).

**IGNORE**: accept the risk.
When: low likelihood OR low cost. Rationale mandatory: "ignoring because [X], and if it happens the real cost is [Y]".

**DOWNSCOPE**: change the scope to eliminate the rabbit hole.
When: high cost, but the feature still works without that zone. Rationale mandatory: "dropping [Z] from scope, the feature stays valid because [reason]".

**SPIKE**: a time-boxed session (1h max) to explore before deciding.
When: not enough is known to choose between the other 3. Rationale mandatory: "can't decide because [X], a 1h spike would give us [Y]".

Present all rabbit holes in **one `AskUserQuestion` batch** — not fragmented one at a time — to avoid splitting attention.

### Step 4 — Structured output

Produce the final recap:

```
Rabbit holes for <TICKET_ID>

Dimensions scanned:
- Technical: [N found | nothing detected]
- Data: [N found | nothing detected]
- User flow: [N found | nothing detected]
- Human: [N found | nothing detected]

Rabbit holes retained after the reality test:

RH-1: [title]
  Decision: [TREAT / IGNORE / DOWNSCOPE / SPIKE]
  Rationale: [sentence]
  Concrete action: [what to do BEFORE coding starts, or "none"]
  Early signal: [what to watch during the build if the decision is IGNORE or SPIKE]

RH-2: [...]

Scope after rabbit holes:
[2-3 updated sentences, folding in any downscopes]

Signals to watch during implementation:
[short list — what toolbox:am-i-stuck should catch mid-build]

Upstream actions required before build:
[concrete list — read file X, ask person Y, etc.]
```

The "Signals to watch" section is meant to **feed `toolbox:am-i-stuck`** during building. It's the bridge between shaping and in-flight detection.

**Persist the `## Rabbit holes` section** to the shared bundle — the same contract `toolbox:decompose` writes to, and `toolbox:plan`/`toolbox:context-validator`/`toolbox:retrospect` read. Resolve the ticket id the same way `toolbox:shape` does:

```bash
TICKET_ID=$(git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]')
```

No match → use the slug already in play for this ticket, same raw-description fallback `toolbox:plan` uses.

Check for an existing bundle first, same lookup `toolbox:shape` uses:

```bash
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```

Write in the bundle's compact form — one line per rabbit hole, not the full structured block above:

```
RH-N: <title> — <decision> — <rationale> — <early signal to watch>
```

- **Bundle exists** (the normal case — `toolbox:shape` wrote it before routing here) → fill in its `## Rabbit holes` section in place, at the position the bundle contract defines. Never touch any other section.
- **No bundle yet** (standalone invocation, no shaping pass ran first) → create one with minimal frontmatter (classification estimated from context, `status: shaped`) plus the `## Rabbit holes` section.
- **`SHAPING_DIR` unset** → persistence isn't available. Say so, show the section in chat only, don't hard-fail.

## Heuristics against over-analysis

**Signs of over-analysis**:
- Identifying > 5 rabbit holes before filtering
- Spending > 15 min on this skill for a medium ticket
- Imagining "what if the user does X while Y while Z" scenarios

**Cutoff rule**: past 15 min with no final list, that's over-analysis. Name the signal and force closure:
> "Past 15 min on rabbit holes for a medium ticket. Over-analysis signal. Closing with the 3 strongest rabbit holes (clearest signal + cost) and moving to the bundle."

**Signs of under-analysis**:
- Zero rabbit holes on a medium ticket with fuzzy zones
- Not possible. Re-run the 4-dimension grid — at least one dimension must contain something.

## Output format

- No emojis
- RH-1, RH-2 numbering for easy reference
- No pep talk
- **Reality test checked systematically** — the deliverable that guards against anxiety dressed up as analysis

## Never do

- Never propose detailed technical solutions (that's brainstorming)
- Never identify > 5 rabbit holes without naming the over-scope signal
- Never use for debugging
- Never use on a trivial ticket
- Never invent exotic rabbit holes to pad the list
- Never ask the user to "think about the rabbit holes" — proposing is this skill's job, they validate
- Never omit the reality test — it's the guardrail against anxiety
- Never skip a dimension without saying "nothing detected"
