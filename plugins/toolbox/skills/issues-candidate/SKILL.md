---
name: issues-candidate
description: Use at the end of a task to surface follow-up work worth filing as tracker issues — deferrals, out-of-scope findings, TODOs added, test/doc gaps, adjacent bugs left alone. Presents a triage table, waits for approval, then files the approved ones with full metadata. Triggers - "issue candidates", "what should I file", "any follow-ups to track", "issues possible", or right after finishing a task/MR.
user-invocable: true
---

# Issues Candidate

End-of-task sweep for work that should become a tracker issue instead of dying in the conversation. **Collect candidates → filter → dedup against the tracker → triage table → wait for approval → file with full metadata.**

The method is host-agnostic; the exact create calls live in the matching tracker file.

```bash
# Tracker detection, in order:
#   1. A tracker MCP/CLI configured for this repo (Linear, Jira, …) — check available tools first
#   2. git remote host → gh issue / glab issue
case "$(git remote get-url origin 2>/dev/null)" in *github*) HOST=github;; *gitlab*) HOST=gitlab;; esac
```
Read `trackers/linear.md`, `trackers/github.md` or `trackers/gitlab.md` for the create/search calls wherever a step says *(see tracker file)*. No tracker reachable → copy-paste fallback (Step 7).

## When to Use
- `/issues-candidate`, or after finishing a task / before opening an MR/PR
- Asked "what follow-ups should I file", "anything to track"

**Don't use** when: mid-task (wait until the work is done), the session was a one-off lookup, or already run once this session.

---

## Step 1 — Survey

```bash
BASE=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || echo origin/main)

git log --oneline "$BASE"..HEAD
git diff "$BASE"...HEAD --stat
git diff "$BASE"...HEAD          # read it; the diff is where half the candidates hide
```

Then re-read the conversation for anything deferred, cut, or noticed-but-not-fixed.

---

## Step 2 — Candidate sources (explicit criteria, not feel)

A candidate must come from one of these. If it doesn't, it's not a candidate.

| # | Source | Concrete signal |
|---|--------|-----------------|
| 1 | **Deferral** | User or you said "later", "out of scope", "not now", "separate issue", "another task" |
| 2 | **Scope cut** | Work the task implied that you deliberately didn't do — name what was dropped |
| 3 | **TODO/FIXME added** | New `TODO`/`FIXME`/`XXX`/`HACK` in the diff with no tracker reference |
| 4 | **Disabled test** | New `skip`/`xfail`/`.only`/`it.skip`/commented-out assertion in the diff |
| 5 | **Adjacent bug** | A real defect you read past because it wasn't the task |
| 6 | **Missing coverage** | New behavior in the diff with no test exercising it |
| 7 | **Doc drift** | The diff invalidates a claim in a README / `CLAUDE.md` / `AGENTS.md` you didn't update |
| 8 | **Blocked-on** | A fix that needs an upstream/kernel/other-repo change first |
| 9 | **Upstream skill output** | A `📋 Tracker issue` recommendation from `review-comments-resolver`, `smallest-footprint`, `mechanical-checks`, `context-validator`, `comment-audit` |
| 10 | **Workaround shipped** | Code that papers over a root cause you chose not to touch |

---

## Step 3 — Filter (drop ruthlessly)

Drop a candidate if any holds:

- **Already filed** — search the tracker before proposing *(see tracker file)*. Cite the existing key instead.
- **Done in this task** — the diff already handles it.
- **No trigger** — "improve X", "consider Y", "maybe refactor Z" with no concrete symptom or reader/user impact. A wish is not an issue.
- **Speculative** — depends on a future that isn't scheduled.
- **Taste-only refactor** — no bug, no cost, just a different shape you'd prefer.
- **Belongs in this MR** — small, in scope, cheaper to fix now. Say so; don't file it.

Cap the proposal at **~6 candidates**. More than that means the bar was too low — re-filter.

---

## Step 4 — Draft each survivor

Per candidate, work out and record:

- **Title** — imperative, names the observable problem, not the fix's shape
- **Type** — `bug` (something is wrong now) vs feature/refactor/chore (nothing broken)
- **Priority** — never "none"; justify in one clause
- **Estimate** — always set, rough is fine
- **Evidence** — `file:line` from the diff, or the conversation moment it surfaced
- **Body** — symptom · where · why it's out of scope here · what a fix involves
- **Relations** — encode ordering as `blockedBy`, never as prose in the body
- **Labels / project / cycle** — per the repo's own conventions (check `CLAUDE.md`/`AGENTS.md` for required label groups; on some repos every issue needs an execution-environment label)

Recommendation per candidate:
- `📋 File` — real, out of scope here, worth a tracker row
- `🔧 Fix now` — small enough that filing costs more than fixing
- `🗑️ Drop` — failed a Step 3 filter (state which)
- `❓ Ask` — you can't tell if it's in scope without the user's intent

---

## Step 5 — Triage table

```
Found {N} candidate(s) from this task ({branch} · {N} commits):

1. 📋 File — 🐛 bug — P2 · E2
   Title: Lead paragraph dropped when a cut file has no heading
   From: TODO added (src/parse.py:212)
   → Real defect, pre-existing, needs its own fixture corpus
   blockedBy: —

2. 🔧 Fix now — refactor — P4 · E1
   Title: Dedup the two path-derivation helpers
   From: scope cut
   → 6 lines, in scope; filing costs more than fixing

3. ❓ Ask — feature — P3 · E3
   Title: Series hub needs a per-tome arc paragraph
   From: deferral ("later" — mid-session)
   → Unclear if this was cut for this cycle or dropped for good

── Not filing ──────────────────────────────────────────────
- Retry logic on the export step — already filed as {KEY}
- "Consider caching the registry" — no trigger, speculative

Default if you say "go": file 📋 with full metadata, apply 🔧, drop 🗑️, ask ❓.
```

Always print the **Not filing** section, even when empty — it shows the filter ran and lets the user override.

**STOP — wait for explicit confirmation.** `AskUserQuestion`: **Go** · **File all** · **Let me pick** · **Skip all**.

---

## Step 6 — Execute

**6A — File `📋`:** create each via the tracker *(see tracker file)* with every field from Step 4 — title, body, type/labels, priority, estimate, relations. An issue missing priority, estimate or labels is incomplete; fill them at creation, don't defer.

**6B — Apply `🔧`:** make the fix, run the repo's checks on touched files, report.

**6C — Resolve `❓`:** ask the user the one question that decides it, then treat as `📋` or `🗑️`.

**6D — Cross-reference:** if a filed issue corresponds to a `TODO`/`FIXME` in the diff, edit the comment to carry the issue key. A TODO without a key is what this skill exists to stop.

**6E — Close an existing issue (only if the session actually answered it):** post the evidence as a comment first, quoting the issue's acceptance criteria and answering each one explicitly — including "not addressed". Writing that comment is what exposes a criterion with no evidence behind it. Only then set the state, and only if every criterion is met. A finding that came out of the same investigation is not automatically the finding the issue asked for; adjacent evidence closes nothing. Partial evidence means the comment stands and the issue stays open.

---

## Step 7 — No tracker reachable

Output each candidate as a copy-paste-ready block — title, body, labels, priority, estimate, relations — and say plainly that nothing was filed.

---

## Step 8 — Report

```
── Filed ───────────────────────────────────────────────────
  📋 {KEY} — {title}  (P2 · E2 · bug)
  📋 {KEY} — {title}  (P3 · E1)
  🔧 1 fixed in-branch (2 files, checks pass)
  🗑️ 2 dropped (1 already filed, 1 speculative)
  ✏️  1 TODO annotated with its issue key
```

---

## Rules

- **Never file without approval.** The table is the deliverable; filing is the follow-up.
- **Dedup before proposing, not after filing.** A duplicate issue is worse than a missing one.
- **Every candidate cites its source row from Step 2.** No row = it's a wish, drop it.
- **A clean task that yields 0 candidates is a successful run.** Don't pad to look thorough.
- **Priority and estimate are never blank.** "I don't know" resolves to the repo's own default, stated out loud.
- **Don't file the task you just did.** Only what it left behind.

---

## Error handling

| Condition | Action |
|-----------|--------|
| Not a git repo / no commits vs base | Fall back to the conversation only; say so |
| Tracker CLI/MCP unauthenticated | STOP — report the auth command, offer Step 7 |
| Tracker search fails | WARN — propose anyway, flag dedup as unverified |
| No candidates survive the filter | DONE — report all-clear with the dropped list |
| Team/project id required and ambiguous | ASK — don't guess the destination |
