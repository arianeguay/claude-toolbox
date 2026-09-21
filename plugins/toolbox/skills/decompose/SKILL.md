---
name: decompose
description: Split a large, fuzzy tracker issue into N independently shippable sub-tickets with a checkable quality bar per sub-ticket. Use when toolbox:shape classifies an issue as large, or the user directly asks to "decompose this", "split into sub-tickets", "shape this feature". Delegates sub-ticket creation to an installed issue-creation skill or the tracker's own create call — never writes to the tracker directly. Do NOT use on trivial/medium issues or to re-decompose an issue that's already a sub-ticket.
user-invocable: true
---

# Decompose — Shape Up splitting

Take a large, fuzzy ticket and produce N **independently shippable** sub-tickets, each with **verifiable quality criteria** — so the split can be judged on explicit checks, not gut feel.

**Principle**: every sub-ticket must be shippable alone. If two sub-tickets only make sense merged together, that's an artificial split.

## When to use

- Called by `toolbox:shape` when triage = large
- Invoked directly on a multi-deliverable ticket

Not for: trivial/medium tickets, creating a ticket from scratch, re-decomposing a ticket that's already a sub-ticket.

## Flow

### Step 1 — Read the ticket

Invoked from `toolbox:shape` → reuse the ticket context it already pulled, don't re-fetch. Invoked standalone → pull it the same way `toolbox:shape` does: a configured tracker MCP/CLI first, else the git-remote-inferred host, else work from whatever text was pasted (same detection order as `issues-candidate`/`start-issue`).

Identify:

- **Distinct deliverables** named ("add X, Y and Z" = 3 candidates)
- **Fuzzy zones** ("to be defined", "would need to check")
- **Implicit dependencies** (backend before frontend, design before implementation)
- **Linked/parent tickets** for context
- **Scope constraints already stated** ("without touching Z", "only for one segment")

Produce a short summary (5-7 lines max):

```
Source ticket: <TICKET_ID> — [title]
Candidate deliverables detected: [short list]
Fuzzy zones: [short list]
Dependencies identified: [short list]
Parent / context: [<PARENT_ID> if applicable]
```

### Step 2 — Propose a split with quality criteria

Propose an initial split into **2-5 sub-tickets**. Never more than 5 on a first pass.

For each proposed sub-ticket:

```
Sub-ticket #N: [proposed title]

Scope: [1 sentence — what it ships]
Appetite: ~X hours of real focus
Likely rabbit holes: [0, 1, 2 — name briefly]
Dependency: [standalone | depends on #M | depends on an external backend]

Quality criteria (checked):
- [✓ or ✗] Title fits one clear line, no jargon
- [✓ or ✗] Ships something observable (UI, behavior, or public component)
- [✓ or ✗] Can merge to trunk without waiting on its neighbors
- [✓ or ✗] Appetite estimable without major ambiguity
- [✓ or ✗] At most 2 predictable rabbit holes

If a criterion is ✗: [reason and a proposed adjustment]
```

If **every** criterion is ✓ for every sub-ticket, the split is prima facie good. If a criterion is ✗ anywhere, **propose an adjustment immediately** (merge, split, reword).

Then, via `AskUserQuestion`:

> "Does this split work?"
> - "Go, create the tickets"
> - "Adjust one sub-ticket's scope"
> - "Merge two sub-tickets"
> - "Drop one"
> - "Change the ship order"

Iterate. Don't create anything in the tracker before explicit confirmation.

### Step 3 — Negotiate ship order with rationale

Once the split is confirmed, determine the order.

**Order criteria, in strict priority** (if criteria conflict, the higher one wins):

1. **Hard dependencies**: a sub-ticket that blocks the others always goes first. Non-negotiable.
2. **Technical risk**: dependencies equal, the sub-ticket with the most uncertainty goes first, to de-risk early.
3. **User value**: risk equal, the sub-ticket with the most visible value goes first.
4. **Can slip**: nice-to-haves go last.

Propose the order with explicit rationale per sub-ticket, naming **which criterion decided it**:

```
Proposed ship order:

1. Sub-ticket A
   Rationale: hard dependency (blocks B and C)

2. Sub-ticket C
   Rationale: more technical risk than B, de-risk early

3. Sub-ticket B — nice-to-have, can slip
   Rationale: user value equivalent to C but lower risk, fine to ship last
```

First to attack: A (name the dominant criterion explicitly in the final answer).

### Step 4 — Scale and focus signals

While decomposing, actively watch for:

**Signal 1 — Sub-ticket multiplication**: past 5 sub-tickets:
> "We're at [N] sub-tickets. Past the recommended threshold. Check: could 2 sub-tickets merge without losing ship independence? If yes, merge them. If no, the parent ticket may be mis-scoped at the root — signal to raise."

**Signal 2 — Cascading technical sub-decisions**: if a sub-ticket's discussion drifts into libraries, patterns, architecture:
> "Stop. This is drifting from shaping into implementation. That decision belongs to building. Note the question under 'likely rabbit holes' and move on."

**Signal 3 — Time elapsed**: if decompose runs past 45 minutes:
> "45 minutes into decompose. Normal ceiling for a large ticket. If there's no stable split within 10 more minutes, that's a signal the original ticket isn't shapable as written — send it back to the author for clarification."

Don't just *note* these signals — name them out loud and propose the concrete action. Explicit, checkable thresholds beat a gut sense that "this feels like too much" — useful for anyone making a scoping call solo, not a trait of one particular working style.

### Step 5 — Delegate creation

Never write directly to the tracker. For each confirmed sub-ticket, delegate:

**(a) First**, check the available-skills list for an environment-installed issue-creation skill (e.g. `linear-issue-creator`, a repo's own `new-ticket`). If one exists, it owns the title, body shape and provenance footer — hand it the field list below and let it draft and create.

**(b) None installed** — use `toolbox:issues-candidate`'s tracker detection (configured tracker MCP/CLI first, else the git-remote-inferred host) and its matching `trackers/<host>.md` **Create** step directly. Add `parentId` (link to the source ticket) and `blockedBy` (per the Step 3 ship order) to that call for sequencing. Never invent a new tracker adapter file — reuse the ones `issues-candidate` already ships.

Per sub-ticket, pass:

- **Title** — action + object, no jargon
- **Context** — 2-4 sentences: link to the parent ticket, why this split
- **Current behavior** — only if bug/improvement
- **What we want** — 1-2 sentences, target end state, not the implementation
- **Parent id** — the source ticket's key (`parentId` — tracker-generic; the exact field name depends on which `trackers/<host>.md` this resolves to)
- **Project** — match the parent's
- **Labels** — inherit from the parent; add a quick-win label if the target tracker has one and appetite is very low
- **Priority** — inherit from the parent, except nice-to-haves → lowest priority

Whichever path is used, let it run its own confirmation flow — don't duplicate it here.

**Creation order**: the ship order confirmed in Step 3.

### Step 6 — Final recap and persist

Once every sub-ticket is created, produce the recap for `toolbox:shape` (or the user, if run standalone):

```
Decompose complete. Parent ticket: <TICKET_ID>

Sub-tickets created (ship order):
1. <KEY-A> — [title] — appetite ~Xh
   Why #1: [sentence]
2. <KEY-B> — [title] — appetite ~Xh
   Why #2: [sentence]
3. <KEY-C> — [title] — appetite ~Xh (nice-to-have)
   Why: [sentence]

First to attack: <KEY-A>

Likely rabbit holes on <KEY-A>:
[short list if already spotted, else "check with toolbox:rabbit-holes"]

Overall split quality check:
- [✓ or ✗] Every sub-ticket can merge independently
- [✓ or ✗] Sum of appetites is consistent with the parent's appetite
- [✓ or ✗] No sub-ticket is pure "setup" or "plumbing"
- [✓ or ✗] Ship order has an explicit reason (not just chronological)
```

Propose: "Want me to run `toolbox:rabbit-holes` on `<KEY-A>` before the bundle, or go straight there?"

**Persist the `## Sub-tickets` section** to the shared bundle — the contract `toolbox:shape`, `toolbox:plan`, `toolbox:context-validator` and `toolbox:retrospect` all read. Resolve the ticket id the same way `toolbox:shape` does:

```bash
TICKET_ID=$(git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]')
```

No match → use the slug already in play for this ticket (the one `toolbox:shape` derived, or the same raw-description fallback `toolbox:plan` uses if none exists yet).

Check for an existing bundle first, same lookup `toolbox:shape` uses:

```bash
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```

- **Bundle exists** (the normal case — `toolbox:shape` wrote it before routing here) → fill in its `## Sub-tickets` section in place, at the position the bundle contract defines. Never touch any other section.
- **No bundle yet** (standalone invocation, no shaping pass ran first) → create one with minimal frontmatter (`classification: large`, `status: shaped`) plus the `## Sub-tickets` section, and say in the recap that no triage ran.
- **`SHAPING_DIR` unset** → persistence isn't available. Say so, show the section in chat only, don't hard-fail.

## Split heuristics (quick reference)

**A good sub-ticket**:
- Clear one-line title
- Ships something observable
- Estimable appetite
- ≤ 2 predictable rabbit holes
- Mergeable without its neighbors

**A bad sub-ticket** (merge or reword):
- "Setup", "prep work", "plumbing" → not a deliverable
- "Research X" / "Investigate Y" if > 2h → flag as a separate spike
- "Refactor A while we're at it" → scope creep, a separate ticket outside the split
- Depends on a backend not yet built → use mocks, or flag as blocked

## Output format

- No emojis
- Numbered lists for sub-tickets (order matters)
- No decorative bullets elsewhere
- No pep talk
- **Quality criteria checked systematically** — this skill's primary deliverable, so the split can be judged on explicit criteria instead of gut feel

## Never do

- Never write directly to the tracker — always via Step 5's delegation (installed issue-creation skill, else the tracker's own Create call)
- Never propose technical approaches / libs / patterns
- Never produce > 5 sub-tickets on a first pass without naming the signal
- Never create a "spike" > 2h without an explicit flag
- Never decompose a ticket that's already a sub-ticket (over-decomposition risk)
- Never omit the checked criteria — they're what externalizes the review instead of relying on gut feel
