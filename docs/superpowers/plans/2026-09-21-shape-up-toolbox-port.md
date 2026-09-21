# Shape Up Toolbox Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Gray-coupled Shape Up shaping flow (6 skills in `~/.claude/skills/`) into 4 generic toolbox skills that fill the `${SHAPING_DIR}` bundle contract `toolbox:plan` and `toolbox:context-validator` already expect but nothing currently produces, plus wire `toolbox:start-issue` to consume that bundle.

**Architecture:** Four new standalone markdown skills (`shape`, `decompose`, `rabbit-holes`, `retrospect`) under `plugins/toolbox/skills/`, each reusing the tracker-detection and bundle-path conventions already established by `plan`, `start-issue`, and `issues-candidate`. One small addendum to `start-issue`'s existing Step 4. No code, no build — this is content authoring against a fixed contract (the bundle format), already validated in the approved spec.

**Tech Stack:** Markdown skill files (Claude Code plugin format), bash snippets for bundle path resolution, no automated test suite (repo convention — see `CLAUDE.md` "Where a Task Runs").

**Spec:** `docs/superpowers/specs/2026-09-21-shape-up-toolbox-port-design.md`

## Global Constraints

Genericization rules — every task applies the ones relevant to it by number (G1-G10), not re-derived per task:

- **G1 — Language:** French Québécois → English. Matches every existing toolbox skill.
- **G2 — Ticket ID:** `GRA-XXXX` → resolved from `TICKET_PREFIX` (`PROFILE.md`) via the exact regex `toolbox:plan` already uses: `git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]'`. No ticket → slug fallback, same as `plan`'s raw-description path.
- **G3 — Persistence path:** hardcoded `/Users/arianeguay/dev/src/claude-shaping/` → `${SHAPING_DIR}` (from `PROFILE.md`), exact lookup `plan` already uses: `[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"`. `SHAPING_DIR` unset → say persistence is unavailable, present the bundle in chat only, don't hard-fail.
- **G4 — Input mechanism:** drop the Desktop/`ask_user_input_v0` branch entirely — every toolbox skill uses `AskUserQuestion` only.
- **G5 — Tracker reads:** same detection order as `issues-candidate`/`start-issue` — configured tracker MCP/CLI first, else git-remote-inferred host, else work from pasted text with no tracker reachable.
- **G6 — Sub-ticket creation (decompose only):** delegate to *(a)* an environment-installed issue-creation skill if the available-skills list has one (same phrasing `start-issue` already uses for its backfill step), else *(b)* `issues-candidate`'s `trackers/<host>.md` **Create** step directly, adding `parentId`/`blockedBy` fields for sequencing. Never a new tracker adapter file.
- **G7 — Persist-a-pattern step (retrospect only):** Gray's `memory_user_edits` is a Desktop-only tool — don't assume it exists. Generic version: if this session exposes some persistent memory/preference mechanism, offer to use it the same way (confirm first, same as Gray); otherwise the pattern only goes into the bundle's own aggregate log (no silent fallback tool invented).
- **G8 — Domain-specific lines:** drop RO/MO and other Gray-clinical-domain example lines. Grid/dimension structure stays; only the example line is dropped.
- **G9 — Framing:** reword AuDHD-specific rationale ("no NT intuition") as universal — explicit checkable criteria beat gut-feel for anyone making a scoping call solo. Same mechanic, generic justification.
- **G10 — Frontmatter:** every new skill gets `user-invocable: true`, matching every existing toolbox skill.

Bundle contract (frontmatter + section list) is fixed in the spec — do not redesign it while porting; if a section doesn't map cleanly, flag it in the task rather than improvising a new field.

---

## Task 1: Branch setup

**Files:** none (git state only)

- [ ] **Step 1: Create the feature branch**

```bash
cd ~/dev/claude-toolbox
git checkout main && git pull origin main
git checkout -b shape-up-toolbox-port
```

- [ ] **Step 2: Confirm branch and clean tree**

```bash
git status
git branch --show-current   # must print shape-up-toolbox-port
```

No commit for this task — it's setup for Task 2's first commit.

---

## Task 2: `toolbox:shape`

**Files:**
- Create: `plugins/toolbox/skills/shape/SKILL.md`

**Interfaces:**
- Consumes: nothing from other new skills (entry point).
- Produces: the bundle at `${SHAPING_DIR}/<TICKET_ID>.md` (or `${SHAPING_DIR}/<slug>.md`) — the exact frontmatter + section contract from the spec's "Bundle contract" section. Routes to `toolbox:decompose` and `toolbox:rabbit-holes` **by those exact names** — Tasks 3 and 4 must create skills invocable under those names.

Source to port from: `~/.claude/skills/ticket-shape/SKILL.md` (orchestrator, full file) + `~/.claude/skills/ticket-triage/SKILL.md` (triage, full file — folded in as an inline step per the spec, not a separate skill).

- [ ] **Step 1: Write frontmatter and opening**

```markdown
---
name: shape
description: Shape Up entry point for a new or in-flight ticket — classifies it (trivial/medium/large) against checkable criteria, then routes to decompose/rabbit-holes/direct-to-plan as the classification calls for. Use when the user pastes a ticket, mentions a tracker key, says "shape this", "is this worth shaping", "new ticket", "I was assigned", or wants to re-enter shaping mid-build ("stuck on <KEY>", "coming back to the shaping of <KEY>"). Produces and persists a shaping bundle at ${SHAPING_DIR}/<KEY>.md for toolbox:plan to consume. Do NOT use to create a ticket from scratch (defer to an issue-creation skill) or for build-time diagnostics (use toolbox:am-i-stuck).
user-invocable: true
---

# Shape — Shaping entry point
```

Port the "Principe de base" / "Ce qu'on décide ici vs building" sections from `ticket-shape/SKILL.md:11-39`, applying G1 and G9. Keep the "golden rule" verbatim in meaning: shaping never decides implementation (lib/pattern/architecture); in Claude Code, reading code to confirm a scope claim is fine, choosing the approach is not.

- [ ] **Step 2: Port activation + flow-selection**

Port `ticket-shape/SKILL.md:41-72` (Activation, flow-selection table) applying G1, G4. Two flows: **main** (new ticket) and **re-entry** (stuck/reshape).

- [ ] **Step 3: Write the main flow — steps 1-2 (fetch + inline triage)**

Step 1 (fetch ticket): apply G5 for the tracker read instead of `Linear:get_issue` (`ticket-shape/SKILL.md:76-87`).

Step 2 (triage, inlined): port the full classification logic from `ticket-triage/SKILL.md:18-136` — the three classes (trivial/medium/large, renamed from TRIVIAL/MOYEN/GROS) with their checkable criteria lists verbatim in structure, the output format (`ticket-triage/SKILL.md:94-120`) including the **mandatory** counter-argument section, and the edge-case rules (`ticket-triage/SKILL.md:124-136`: ambiguous-between-two-classes always rounds up, vague-ticket-with-no-description defaults to large, urgent doesn't change the class). Apply G1, G8 (no domain examples needed here — the examples in triage are already generic UI/backend/migration examples, keep them).

Routing table (`ticket-shape/SKILL.md:95-104`) stays as-is structurally: trivial → skip to `toolbox:plan`; medium+0 fuzzy → bundle direct; medium+1-2 fuzzy → `toolbox:rabbit-holes`; large → `toolbox:decompose`. Never launch more than one downstream skill at a time.

- [ ] **Step 4: Write the time-box / focus check-in step**

Genericize `ticket-shape/SKILL.md:106-140` (temporal surveillance + hyperfocus detection) per G9:
- Horizontal (3+ different tickets opened this session): same check-in line, reworded without AuDHD framing — "3 different tickets are open in this session — which one closes before the next opens?"
- Vertical (5+ sub-tickets or cascading sub-decisions in <2h): same threshold, generic wording.
- Time thresholds (~15/30/45 min): keep the three-tier escalation, generic wording, same "propose closing with current bundle" pattern.
- Tooling-shopping signal (discussing libs/patterns mid-shaping): keep — "note the question in the bundle, move on."

- [ ] **Step 5: Write bundle production (step 5) using the spec's shared contract**

Port `ticket-shape/SKILL.md:142-231` structurally, but the bundle template itself comes from the spec's "Bundle contract" section (already fixed — do not re-derive). Include:
- The existing-file check (don't silently overwrite — offer overwrite/append/cancel, `ticket-shape/SKILL.md:214-216`).
- Persistence using G3's exact bash pattern.
- The "propose retrospect once shipped" behavior (`ticket-shape/SKILL.md:224-231`), pointing at `toolbox:retrospect` by name.

- [ ] **Step 6: Write the re-entry flow**

Port `ticket-shape/SKILL.md:233-234` (acknowledge without judgment, one line, generic wording per G9) then **replace** the Gray original's own diagnostic (`ticket-shape/SKILL.md:237-271`, the "what's the blocker / how long" question pair) with a single line: point at `toolbox:am-i-stuck` for the diagnostic. Keep only the **output** side: if `am-i-stuck`'s recommendation is "reshape," `shape` re-enters and appends a `## Reshape` section (format from the spec's bundle contract) to the existing bundle file — port the file-handling logic from `ticket-shape/SKILL.md:277-309` (check existing file, update `status: reshaped`, append under a new header, never overwrite), applying G1/G2/G3.

- [ ] **Step 7: Port "never do" + output-format sections**

Port `ticket-shape/SKILL.md:311-329` applying G1 (drop the Québécois-French-specific lines, e.g. "ne pas traduire les termes"; keep: never produce code/pseudocode, never decide architecture, never create sub-tickets directly — always via the delegation in G6, never close on pep talk, every decision needs an explicit rationale).

- [ ] **Step 8: Manual dry-run verification**

Three synthetic scenarios, run in a scratch directory with `SHAPING_DIR` pointed at a temp folder:

```bash
export SHAPING_DIR=/tmp/shape-up-dryrun && mkdir -p "$SHAPING_DIR"
```

1. **Trivial**: paste a one-line, clearly-bounded fake ticket ("fix button padding on the settings dialog"). Confirm: triage verdict = trivial, output includes counter-argument section, routes straight to "skip to toolbox:plan", no bundle file written (trivial skips bundling per the routing table — if the skill as written *does* write one for trivial, that's a deviation from `ticket-shape/SKILL.md:99` — fix it).
2. **Medium + 1 fuzzy zone**: paste a fake ticket ("add a filter dropdown to the existing worklist, exact filter values TBD"). Confirm: triage = medium, 1 fuzzy zone detected, routes to `toolbox:rabbit-holes` (don't need rabbit-holes to actually exist yet for this check — confirm the routing text names it correctly).
3. **Large**: paste a fake ticket ("add X, Y and Z to the reporting page, unifies the old and new report formats"). Confirm: triage = large (multiple distinct deliverables signal), routes to `toolbox:decompose`, and confirm a bundle IS written for large per the routing table, with correct frontmatter (`classification: large`, `status: shaped`).

Check each bundle file against the spec's frontmatter/section contract exactly (`cat "$SHAPING_DIR"/*.md`).

- [ ] **Step 9: Commit**

```bash
cd ~/dev/claude-toolbox
git add plugins/toolbox/skills/shape/SKILL.md
git commit -m "feat(shape): add Shape Up shaping entry point, ported from Gray ticket-shape+ticket-triage"
```

---

## Task 3: `toolbox:decompose`

**Files:**
- Create: `plugins/toolbox/skills/decompose/SKILL.md`

**Interfaces:**
- Consumes: invoked by `toolbox:shape`'s routing table when classification = large. Reads the same tracker context `shape` already fetched (or re-fetches per G5 if invoked standalone).
- Produces: sub-tickets in the tracker (via G6 delegation), and the `## Sub-tickets` section of the bundle `shape` will write.

Source: `~/.claude/skills/ticket-decompose/SKILL.md`, full file (334 lines read this session across two reads).

- [ ] **Step 1: Write frontmatter**

```markdown
---
name: decompose
description: Split a large, fuzzy tracker issue into N independently shippable sub-tickets with a checkable quality bar per sub-ticket. Use when toolbox:shape classifies an issue as large, or the user directly asks to "decompose this", "split into sub-tickets", "shape this feature". Delegates sub-ticket creation to an installed issue-creation skill or the tracker's own create call — never writes to the tracker directly. Do NOT use on trivial/medium issues or to re-decompose an issue that's already a sub-ticket.
user-invocable: true
---

# Decompose — Shape Up splitting
```

- [ ] **Step 2: Port steps 1-2 (read + propose split)**

Port `ticket-decompose/SKILL.md:19-76` (deliverables/fuzzy-zones/dependencies extraction, the per-sub-ticket proposal format with its 5-criterion quality checklist, the "propose adjustment immediately if any criterion fails" rule, the confirm-before-create question). Apply G1, G2, G5.

- [ ] **Step 3: Port step 3 (ship order)**

Port `ticket-decompose/SKILL.md:78-104` verbatim in structure — the 4-criterion strict-priority ordering rule (hard dependencies > technical risk > user value > can-slip), with the example output block. Apply G1.

- [ ] **Step 4: Port step 4 (hyperfocus/scale signals) genericized**

Port `ticket-decompose/SKILL.md:106-119` applying G9 — same three thresholds (5+ sub-tickets, tooling/lib discussion mid-decompose, 45min elapsed), generic wording, same "name it out loud, propose the concrete action" pattern.

- [ ] **Step 5: Write step 5 (delegate creation) per G6**

Replace `ticket-decompose/SKILL.md:121-137` (hardcoded `linear-issue-creator` delegation) with G6's two-tier delegation. Keep the per-sub-ticket field list (title, context, current-behaviour-if-applicable, what-we-want, parent id, project, labels, priority — `ticket-decompose/SKILL.md:125-133`) but note parent id and priority/label inheritance are tracker-generic concepts, not Linear-specific — keep the field list, genericize the field names if the target tracker differs (defer field-name mapping to whichever tracker file G6 resolves to).

- [ ] **Step 6: Port step 6 (final recap) and heuristics/output rules**

Port `ticket-decompose/SKILL.md:139-200` (recap format, "good vs bad sub-ticket" heuristics, output-format rules, never-do list) applying G1, G6 (replace the two `linear-issue-creator` mentions in the never-do list with the generic delegation phrasing).

- [ ] **Step 7: Manual dry-run verification**

Using the "large" scenario ticket from Task 2 Step 8.3 (three distinct deliverables: X, Y, Z on a reporting page): run `decompose` standalone. Confirm:
- Produces 2-5 sub-tickets, each with the 5-criterion checklist filled in (✓/✗ per criterion, not omitted).
- Ship order has an explicit dominant-criterion rationale per sub-ticket (not just chronological).
- Asks for confirmation before any tracker-write attempt (dry-run — decline the confirmation, verify it stops there without writing anything).
- The final recap block matches the format in `ticket-decompose/SKILL.md:143-164` structurally.

- [ ] **Step 8: Commit**

```bash
git add plugins/toolbox/skills/decompose/SKILL.md
git commit -m "feat(decompose): add Shape Up sub-ticket splitting, ported from Gray ticket-decompose"
```

---

## Task 4: `toolbox:rabbit-holes`

**Files:**
- Create: `plugins/toolbox/skills/rabbit-holes/SKILL.md`

**Interfaces:**
- Consumes: invoked by `toolbox:shape` (medium + 1-2 fuzzy zones) or `toolbox:decompose`'s recap suggestion, or directly by the user.
- Produces: the `## Rabbit holes` section of the bundle, plus a "signals to watch" list meant to feed `toolbox:am-i-stuck` during build (named cross-reference, no code coupling).

Source: `~/.claude/skills/ticket-rabbit-holes/SKILL.md`, full file (171 lines, both reads this session).

- [ ] **Step 1: Write frontmatter**

```markdown
---
name: rabbit-holes
description: Scan a ticket for technical/data/user-flow/coordination rabbit holes using a fixed 4-dimension grid, and produce an explicit treat/ignore/downscope/spike decision for each one that passes a concrete-signal-plus-estimable-cost reality test. Use after toolbox:shape classifies medium with 1-2 fuzzy zones, after toolbox:decompose on the first sub-ticket to ship, or when the user asks "what could go wrong here". Never use on a trivial ticket or for live debugging (the pitfall is already visible by then).
user-invocable: true
---

# Rabbit Holes — systematic risk scan
```

- [ ] **Step 2: Port step 1 (4-dimension scan)**

Port `ticket-rabbit-holes/SKILL.md:22-59` — the fixed grid (Technical / Data / User flow / Human-coordination) with its question lists per dimension. Apply G1, G8 (drop the RO-vs-MO line in the user-flow dimension, keep everything else). Keep the "must answer explicitly per dimension — 'nothing detected' or list it, never silently skip a dimension" rule.

- [ ] **Step 3: Port step 2 (reality test + 5-max limit)**

Port `ticket-rabbit-holes/SKILL.md:61-84` verbatim in structure — per-rabbit-hole format (dimension tag, the two-part reality test: concrete signal + estimable cost, both required or it's not a real rabbit hole), the hard 5-per-pass cap, and the escalation line when >5 are found (suggest re-decompose or over-analysis, ask the user which). Apply G1.

- [ ] **Step 4: Port step 3 (4-way decision) and step 4 (structured output)**

Port `ticket-rabbit-holes/SKILL.md:86-137` — the four decisions (Treat/Ignore/Downscope/Spike) with their trigger conditions and mandatory-rationale phrasing, the batch-presentation rule (all rabbit holes in one `AskUserQuestion` round per G4, not fragmented), and the final structured recap format including the "signals to watch during build → feeds am-i-stuck" section and "upstream actions required before build" list. Apply G1, G4.

- [ ] **Step 5: Port over/under-analysis heuristics and never-do list**

Port `ticket-rabbit-holes/SKILL.md:139-171` applying G1. Keep the hard 15-minute cutoff rule for a medium ticket (force closure with the 3 strongest rabbit holes if exceeded) and the under-analysis check (0 rabbit holes on a medium ticket with fuzzy zones is treated as a bug in the pass, not a valid result — re-run the grid).

- [ ] **Step 6: Manual dry-run verification**

Using the "medium + 1 fuzzy zone" scenario from Task 2 Step 8.2 (filter dropdown, values TBD): run `rabbit-holes` standalone. Confirm:
- All 4 dimensions get an explicit answer (including "nothing detected" where applicable) — none silently skipped.
- At least 1 rabbit hole is found (the "values TBD" fuzzy zone should surface as a Human-coordination dimension hit at minimum) and passes the two-part reality test.
- Each rabbit hole gets one of the 4 decisions with a rationale sentence, not just a label.
- Output includes the "signals to watch" and "upstream actions" sections.

- [ ] **Step 7: Commit**

```bash
git add plugins/toolbox/skills/rabbit-holes/SKILL.md
git commit -m "feat(rabbit-holes): add Shape Up risk-grid scan, ported from Gray ticket-rabbit-holes"
```

---

## Task 5: `toolbox:retrospect`

**Files:**
- Create: `plugins/toolbox/skills/retrospect/SKILL.md`

**Interfaces:**
- Consumes: reads `${SHAPING_DIR}/<TICKET_ID>.md` using the exact same lookup `toolbox:plan` Step 0 already uses (G3). Distinct from `toolbox:what-did-we-learn` — no shared state, no overlap in trigger phrasing.
- Produces: an appended `## Retrospect` section on the bundle file (frontmatter `status` → `shipped`), and a row in `${SHAPING_DIR}/_calibration_log.md`.

Source: `~/.claude/skills/ticket-retrospect/SKILL.md`, full file (239 lines, both reads this session).

- [ ] **Step 1: Write frontmatter**

```markdown
---
name: retrospect
description: Quick post-ship review (5-10 min max) of a shipped ticket to calibrate shaping accuracy — asks exactly 3 fixed questions comparing shaped vs. actual (rabbit holes, scope drift, classification accuracy), writes a structured gap summary plus at most 1 adjustment to the bundle, and logs a data point to the aggregate calibration log. Use after the user says a ticket shipped/merged/is in review, or asks for "a retrospect on <KEY>". Never use mid-build (see toolbox:am-i-stuck) or on an abandoned ticket. Distinct from toolbox:what-did-we-learn, which captures generalizable knowledge, not estimate calibration.
user-invocable: true
---

# Retrospect — post-ship shaping calibration
```

- [ ] **Step 2: Port step 1 (fetch context) per G3**

Port `ticket-retrospect/SKILL.md:28-44` using G3's exact bundle lookup instead of the hardcoded path. Keep: bundle is source of truth when present; no bundle → work from what the user remembers, don't force it, note the missing-bundle gap in the final recap as a process signal. Apply G5 for the supplementary tracker read (final status, created/closed dates, blocker comments) instead of `Linear:get_issue`.

- [ ] **Step 3: Port step 2 (exactly 3 questions)**

Port `ticket-retrospect/SKILL.md:45-76` verbatim in structure — the 3 fixed questions (rabbit holes outcome, scope drift direction, classification accuracy) with their exact option sets. Apply G1, G4.

- [ ] **Step 4: Port step 3 (gap analysis rules)**

Port `ticket-retrospect/SKILL.md:77-95` — the causal-analysis rules per answer combination (classification-off → trace to rabbit-holes/triage miss; rabbit-hole-missed → follow-up question about which of the 4 dimensions should have caught it; scope-moved → follow-up on direction/reason, flag (b) as a vertical-hyperfocus pattern per G9's generic wording). Apply G1, G9.

- [ ] **Step 5: Port step 4 (summary format)**

Port `ticket-retrospect/SKILL.md:96-123` verbatim in structure — the fixed summary block (gaps observed, dominant cause, 1-2 sentence learning, pattern-to-watch, at-most-1 flow adjustment). Apply G1.

- [ ] **Step 6: Write step 5 (persist-a-pattern) per G7**

Replace `ticket-retrospect/SKILL.md:127-143` (Gray's `memory_user_edits` call) with G7's generic version: if a persistent memory/preference mechanism is available in this session, offer to use it (confirm first, exact same gating as the Gray original — never persist without explicit confirmation); otherwise the pattern goes into the bundle's own `## Patterns observed` section only (append, don't invent a tool call that may not exist).

- [ ] **Step 7: Port step 5.5 (aggregate calibration log) per G2/G3**

Port `ticket-retrospect/SKILL.md:145-177` — the **no-confirmation-needed** auto-write to the aggregate log (this is raw data capture, not a behavior change, so it stays ungated per the Gray original's own reasoning at line 177). Path: `${SHAPING_DIR}/_calibration_log.md` (was hardcoded). Header block and table row format port verbatim (`ticket-retrospect/SKILL.md:153-167`), applying G1/G2 to column values (trivial/medium/large instead of TRIVIAL/MOYEN/GROS).

- [ ] **Step 8: Port step 6 (update bundle file) and strict rules**

Port `ticket-retrospect/SKILL.md:179-239` — bundle status transition (`in_progress`/`reshaped` → `shipped`), the appended `## Retrospect — <timestamp>` section format, the hard 10-minute cap, the "judge the process, not the person" rule, the max-1-adjustment rule, output-format rules, never-do list. Apply G1, G7 (drop the `userMemories`/`userPreferences` auto-modify prohibition's Desktop-specific tool name, keep the underlying rule: never persist a behavior change without explicit confirmation).

- [ ] **Step 9: Manual dry-run verification**

Reuse the bundle written in Task 2 Step 8.3 (the "large" scenario) as a pre-existing shaped ticket. Manually edit its frontmatter `status` to `in_progress` first (simulating that `plan` ingested it). Run `retrospect` on that ticket id. Confirm:
- Exactly 3 questions asked, no more.
- A gap-analysis line appears referencing the actual classification (`large`) from the bundle.
- Summary block matches the fixed format.
- `${SHAPING_DIR}/_calibration_log.md` is created (didn't exist before) with the header and exactly one data row.
- The original bundle file now has `status: shipped` and an appended `## Retrospect` section — original `## Scope`/`## Classification` sections untouched.

- [ ] **Step 10: Commit**

```bash
git add plugins/toolbox/skills/retrospect/SKILL.md
git commit -m "feat(retrospect): add post-ship shaping calibration, ported from Gray ticket-retrospect"
```

---

## Task 6: `toolbox:start-issue` bundle-check addendum

**Files:**
- Modify: `plugins/toolbox/skills/start-issue/SKILL.md` (Step 4, currently the simple/complex build-triage — read this session, criteria list and the two verdict paragraphs)

**Interfaces:**
- Consumes: the same bundle at `${SHAPING_DIR}/<TICKET_ID>.md` (G3), specifically its `classification` frontmatter field.
- Produces: no change to `start-issue`'s own outputs (verdict line, downstream `toolbox:plan` call) — only changes what decides the verdict when a bundle exists.

- [ ] **Step 1: Locate the exact insertion point**

```bash
grep -n "^## Step 4" plugins/toolbox/skills/start-issue/SKILL.md
```

Insert immediately after the `## Step 4 — Triage: simple or complex` heading, before the existing "Read enough code to answer this honestly" line.

- [ ] **Step 2: Add the bundle-check subsection**

Start-issue's Step 0 resolves the key narratively (as `<KEY>` in prose, e.g. into the tracker adapter calls) — it does not carry a `$TICKET_ID` shell variable forward into Step 4. Don't assume one exists; derive it fresh, same as `toolbox:plan` Step 0 does.

Insert:

```markdown
**Check for a shaping bundle first.**

```bash
TICKET_ID=$(git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]')
BUNDLE="${SHAPING_DIR}/${TICKET_ID}.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```

- **Bundle found:** use its `classification` field instead of re-deriving simple/complex below. `trivial`/`medium` → fall through to the criteria below as normal. `large` → this issue is expected to already be one of `toolbox:decompose`'s sub-tickets (created with a parent link) — plan it directly via `toolbox:plan`, skipping the criteria below. If it's marked `large` but carries no parent link, say so explicitly — decomposition may not have happened yet, and planning it flat risks the exact problem shaping exists to avoid.
- **No bundle:** the criteria below decide as they do today, with one addition to the Complex list: the issue body lists multiple distinct deliverables and has no parent ticket → recommend running `toolbox:shape` before planning, rather than silently planning a ticket that should have been decomposed first.

```

- [ ] **Step 3: Verify the existing Simple/Complex criteria lists are untouched**

```bash
git diff plugins/toolbox/skills/start-issue/SKILL.md
```

Confirm the diff is additive only — the existing `**Simple**`/`**Complex**` bullet lists, and every step after Step 4, are byte-identical to before.

- [ ] **Step 4: Manual dry-run verification**

Two scenarios:
1. Point `TICKET_ID`/`SHAPING_DIR` at the `large`-classified bundle from Task 2 Step 8.3 (with a parent link added manually, simulating a real decompose run). Walk through `start-issue`'s Step 4 language by hand: confirm it reads the bundle, sees `large` + parent link, and the text says "plan it directly" rather than invoking the Simple/Complex criteria.
2. Same bundle, but with the parent-link line removed. Confirm the text flags the missing parent link explicitly.
3. No bundle at all, fake issue body with 3 distinct deliverables ("add CSV export, add PDF export, and a settings toggle for both") and no parent — confirm the Complex-list addition fires and recommends `toolbox:shape`.

- [ ] **Step 5: Commit**

```bash
git add plugins/toolbox/skills/start-issue/SKILL.md
git commit -m "feat(start-issue): check for a shaping bundle before the simple/complex heuristic"
```

---

## Task 7: Integration dry-run + PR

**Files:** none (verification + PR only)

- [ ] **Step 1: Full-chain dry-run**

Fresh scratch scenario, `SHAPING_DIR` pointed at a clean temp dir. Walk one ticket through the entire chain by hand: `shape` (large verdict) → `decompose` (produces sub-tickets, decline actual tracker write) → `rabbit-holes` on the first sub-ticket → back to `shape` to finalize the bundle → `retrospect` once marked shipped. Confirm the bundle file accumulates sections correctly at each stage and no stage clobbers a previous section.

- [ ] **Step 2: Confirm `toolbox:plan` and `toolbox:context-validator` can read the produced bundle**

Read `plugins/toolbox/skills/plan/SKILL.md` Step 0 and `plugins/toolbox/skills/context-validator/SKILL.md`'s scope-source section again side by side with the bundle produced in Step 1. Confirm every field they read (`classification`, `## Scope`, `## Reshape`) is present and named exactly as they expect — this is the one check that proves the contract actually closed, not just that the new skills produce *something*.

- [ ] **Step 3: Push and open PR**

```bash
git push -u origin shape-up-toolbox-port
gh pr create --title "Port Shape Up shaping flow into toolbox (shape, decompose, rabbit-holes, retrospect)" --body "$(cat <<'EOF'
## Summary
- Adds toolbox:shape, toolbox:decompose, toolbox:rabbit-holes, toolbox:retrospect — genericized from the 6 Gray-coupled ticket-* skills
- Fills the ${SHAPING_DIR} bundle contract toolbox:plan and toolbox:context-validator already expected but nothing produced
- Adds a bundle-check to start-issue's Step 4 so both entry points (shape-first and start-issue-first) agree on classification

## Spec
docs/superpowers/specs/2026-09-21-shape-up-toolbox-port-design.md

## Test plan
- [ ] shape: trivial/medium/large dry-runs (done during build, see plan Task 2 Step 8)
- [ ] decompose: large-ticket dry-run (Task 3 Step 7)
- [ ] rabbit-holes: medium-ticket dry-run (Task 4 Step 6)
- [ ] retrospect: full bundle lifecycle dry-run (Task 5 Step 9)
- [ ] start-issue: bundle-found / no-parent-link / no-bundle dry-runs (Task 6 Step 4)
- [ ] Full-chain integration dry-run (Task 7 Step 1)
EOF
)"
```

- [ ] **Step 4: Report the PR URL**

No merge — leave it for review, matching the repo's now-current branch+PR convention for skill changes.
