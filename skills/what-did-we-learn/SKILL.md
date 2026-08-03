---
name: what-did-we-learn
description: Use at the end of a session, MR/PR, or feature to capture generalizable learnings worth persisting beyond the conversation. Trigger when the user says "what did we learn", "any learnings to capture", "should we memorize this", or naturally at the end of a meaty session. Distinct from estimate-calibration retrospectives, which score a shipped unit of work rather than capturing knowledge.
---

# What Did We Learn

Capture generalizable knowledge from the current session before it's lost. Differentiate signal from noise — most session details are ephemeral and shouldn't be persisted.

**Core principle:** memory persistence is *expensive* (every saved memory loads into future contexts). The bar is high: would future-Claude be meaningfully more helpful with this saved? If not, skip.

---

## Distinction from estimate-calibration retrospectives

Some setups have a separate retrospective that scores a shipped unit of work (e.g. a `ticket-retrospect`-style skill, if yours has one). That is a different job from this one:

| Job | When | Output |
|---|---|---|
| Estimate calibration | Post-ship of a specific tracked task | Shaping vs reality, what to adjust for the next similar task |
| `toolbox:what-did-we-learn` | Post-session, post-MR/PR, post-feature | Generalizable knowledge: memories, instruction-file updates, skill/agent modifications |

If the user just shipped a tracked task and you have a calibration retrospective, propose it first; this skill is broader and captures things it doesn't (codebase patterns, workflow rules, skill calibration notes).

---

## When To Use

- User says: "what did we learn", "any learnings", "should we memorize this", "anything to update", "capture lessons"
- End of a meaty session involving: corrections, codebase pattern discoveries, workflow disagreements, skill failures, architectural insights
- Right before context window compaction would lose the insight

**Don't use** when:
- Session was a one-off lookup or trivial fix
- User is mid-task — wait until the work is done
- Already invoked once in the same session (don't re-run)

---

## Pipeline

```
1. Survey the session
2. Categorize candidates
3. Filter against "do not save" rules
4. Present grouped list with recommendations
5. Wait for user approval (go / pick / edit / skip)
6. Apply approved items, propose CLAUDE.md update path (don't auto-commit)
7. Final summary
```

---

## Step 1 — Survey the session

Pull from these sources, in order:

```bash
# Detect the base branch (upstream tracking, else the remote's default, else main)
BASE=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || echo origin/main)

# Recent commits on the active branch (best signal — reflects actual decisions)
git log --oneline "$BASE"..HEAD 2>/dev/null | head -20

# Files touched
git diff "$BASE"...HEAD --name-only 2>/dev/null

# If on the base branch / no upstream, fall back to the conversation context
```

Then re-read the conversation for:
- User corrections ("no", "don't", "stop doing X")
- User confirmations of non-obvious choices ("yes exactly", "perfect, keep that")
- Workflow rules stated by the user or a teammate (chat screenshots, "X said")
- Codebase patterns discovered (sibling components, shared SCSS, established conventions)
- Skill/agent false positives or false negatives (the agent flagged X but X was correct convention; the skill missed Y)
- Architectural insights surfaced (a non-obvious invariant, a library gotcha, a data-flow constraint)

---

## Step 2 — Categorize candidates

Map each candidate to one of:

| Category | File prefix | When |
|---|---|---|
| **Feedback** | `feedback_*.md` | A rule the user/team has now stated. Includes "why" and "how to apply." |
| **Project** | `project_*.md` | A non-derivable fact about ongoing work, an architectural debt, or a constraint. Decays — stamp with date. |
| **Reference** | `reference_*.md` | A pointer to where info lives (chat channel, dashboard, repo or issue tracker, codebase pattern across multiple files). |
| **User** | `user_*.md` | Something about *who the user is* (role, expertise, preferences). |
| **CLAUDE.md (global)** | `~/.claude/CLAUDE.md` | Personal rule, applies across all projects (e.g. "always respond in English for deliverables"). |
| **CLAUDE.md (project)** | `<repo>/CLAUDE.md` | Codebase convention checked into the repo (e.g. naming convention, anti-pattern to avoid). |
| **Skill modification** | `~/.claude/skills/<skill>/SKILL.md` | A skill that produced a false positive/negative worth fixing. |
| **Agent modification** | Same | An agent that systematically misses a pattern. |

---

## Step 3 — Filter against "do not save" rules

These are already in `~/.claude/CLAUDE.md` under "auto memory" — apply them ruthlessly:

- **Code-derivable** — anything `git grep` or reading the current file reveals. Skip file paths, function signatures, conventions visible in any single file.
- **Git history** — who changed what, when. `git log` / `git blame` are authoritative.
- **Debug solutions / fix recipes** — the fix is in the code, the commit message has the context.
- **Already in CLAUDE.md** — check before adding a duplicate.
- **Ephemeral** — in-progress task state, current conversation context.

If the user explicitly asks to save something that fails these filters, push back briefly and ask what was *surprising* or *non-obvious* — that's the part worth keeping.

---

## Step 4 — Present grouped list

Format the proposal so the user can scan in <30s:

```
── Memories to add ──────────────────────────────────────────────
1. feedback_<topic>.md — <one-line hook>
2. project_<topic>.md — <one-line hook>
3. reference_<topic>.md — <one-line hook>

── CLAUDE.md updates ────────────────────────────────────────────
4. <repo>/CLAUDE.md — add <N> lines under <section> (codebase convention)
5. ~/.claude/CLAUDE.md — no changes proposed

── Skill / agent modifications ──────────────────────────────────
6. <skill> — note: <observed gap>, suggest <change>

── Not worth saving ─────────────────────────────────────────────
- <thing the user might expect to save> — reason: code-derivable / ephemeral / etc.

Default if you say "go": apply all of #1–#5, log #6 as a note for later.
```

Always include the "Not worth saving" section even if empty — shows the filter ran, and gives the user a chance to override if they actually want one of those.

Then call `AskUserQuestion`:
- **Go** — apply all proposed
- **Pick** — user gives comma-separated numbers
- **Edit** — user wants to revise wording
- **Skip** — capture nothing

**Wait for the user before writing anything.**

---

## Step 5 — Apply approved items

For each approved memory:
1. Write the file at `<memory-dir>/<filename>.md` with frontmatter (`name`, `description`, `type`).
2. Body structure for `feedback_*` and `project_*`: lead with the rule/fact, then `**Why:**` line and `**How to apply:**` line. Knowing *why* lets future-Claude judge edge cases.
3. Update `<memory-dir>/MEMORY.md` index — one line, ~150 chars, `- [Title](file.md) — one-line hook`.

For instruction-file (CLAUDE.md / AGENTS.md / etc.) updates:
- Edit the file in place — but **do not auto-commit**. Show the diff and let the user decide the ship path (bundle into current work, standalone change, or whatever their project convention is).

For skill/agent modifications:
- If it's a small fix (a regex, a sentence in the brief), apply directly with `Edit`.
- If it's a behavioral change (new step, new agent), present the proposed diff first and confirm.

---

## Step 6 — Final summary

```
── Captured ────────────────────────────────────────────────────
  ✅ <N> memories written
  ✅ <repo>/CLAUDE.md edited (uncommitted — your call on the ship path)
  ⚠️  Skill <name> flagged for refinement (not changed)
  ⏭️  <N> candidates skipped per "not worth saving"
```

If the user deferred the instruction-file change to a reviewer or a separate step, surface that as the active follow-up rather than leaving it implied.

---

## Rules

- **Never auto-commit CLAUDE.md edits.** They're convention proposals — user decides the ship path.
- **Don't propose more than ~5 memories per session.** If the list is bigger, the bar was too low; re-filter.
- **Each memory needs a `Why:` line.** No why = brittle memory that won't survive edge cases.
- **Cite the moment it surfaced.** "User said X on <date> after <event>" beats "user wants X" — context lets future-Claude judge whether the rule still applies.
- **Calibrate when a skill or agent failed.** If a skill or agent missed a pattern (false negative) or flagged a correct convention (false positive), the user's first instinct is to fix the symptom; this skill should also flag the underlying skill/agent gap as a modification candidate.
- **Honest filter.** Most session details are ephemeral. A clean run that captures 0–1 memory is a successful run. Don't pad to look productive.
