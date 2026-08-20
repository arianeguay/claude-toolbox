---
name: start-issue
description: Take a tracker issue from "link pasted" to "PR open, issue in review" — reads the issue, creates the branch/worktree the tracker names, moves it to In Progress, builds it (directly if simple, plan-first if complex), opens the PR/MR, then moves it to In Review. Use whenever the user drops a bare issue link or key (a Linear URL, `ABC-123`) with no other instruction, or says "start this issue", "pick this up", "commence ce ticket". Do NOT use to file a new issue (that's `issues-candidate`) or to plan without building.
user-invocable: true
---

# Start issue

One entry point for "here's a ticket, go". A bare issue link is a full instruction: it means run every step below, in order, without asking between them.

**Principle:** the tracker is the source of truth for the branch name, the state names, and the scope. Never invent a branch name the tracker already owns, and never leave the issue's state lying about where the work actually is.

The build steps delegate to the other toolbox skills — this file is the spine, not a reimplementation.

---

## Step 0 — Resolve the input

Accept any of: a tracker URL, a bare key (`ABC-123`), or "the current branch's issue".

```bash
git branch --show-current | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]'
```

Pick the tracker adapter from `trackers/<TRACKER>.md` (`TRACKER` in `PROFILE.md`, else inferred from the URL host). No adapter for the host → stop and say so; don't half-run the flow.

## Step 1 — Read the issue

Read the full issue: title, description, labels, state, estimate, priority, relations, **and its comments** — decisions often live only there. Follow `blockedBy` links far enough to know whether this issue is startable at all.

**A blocked issue does not start.** If an open blocker exists, say which one and stop. That is the only step that aborts the flow silently-free.

**Backfill before building.** If the user's `CLAUDE.md`/`PROFILE.md` defines an issue standard (title form, description sections, required labels, estimate, priority), bring the issue up to it now, in one save, without asking. No standard defined → skip this, don't invent one.

**Re-scope a stale issue.** If part of it already shipped, rewrite the description down to what actually remains and say the scope changed. Never implement a spec the codebase outgrew.

## Step 2 — Branch and worktree

Get the branch name **from the tracker** (adapter says how). Trackers own this — a hand-rolled name breaks their branch↔issue linking. No tracker-provided name → derive `<key-lowercased>-<kebab-title>` and say you derived it.

Create the worktree on that branch:

```
EnterWorktree  name: <tracker branch name>
```

Every task gets its own worktree — never branch-switch the main checkout. If the tool isn't available:

```bash
git worktree add -b <branch> .claude/worktrees/<branch> origin/<default-branch>
```

Confirm you're in it (`pwd`, `git branch --show-current`) before touching a file.

## Step 3 — Move the issue to In Progress

Adapter step. Set the in-progress state and assign the issue to the user if it's unassigned. Do this **after** the worktree exists, so the tracker never claims work that has no branch.

## Step 4 — Triage: simple or complex

Read enough code to answer this honestly; don't classify from the title.

**Simple — build directly.** All of:
- ≤3 files touched, no new file that needs a home decision
- no new dependency, schema/migration, or public API/contract change
- the approach is obvious from the issue plus the code you just read
- no open product/UX decision left in the issue
- an existing test path covers it (or the test to add is obvious)

**Complex — plan first.** Any one of:
- 4+ files, or a change crossing package/service boundaries
- new dependency, migration, or contract change
- two defensible approaches with a real trade-off
- the issue leaves a decision to whoever picks it up
- you can't name the verification before writing code

Print the verdict and the criterion that decided it, in one line.

**Complex path:** invoke `toolbox:plan`. Present the trade-off in the side-by-side pros/cons form with a recommendation, get one confirmation, then build. That confirmation is the *only* stop in the whole flow.

## Step 5 — Build

Small, logical commits — one per change, not one per session. Commit as you go, not in a pile at the end.

Scope discipline: every changed line traces to the issue. Findings outside it go to `toolbox:issues-candidate` at the end, not into this diff.

## Step 6 — Ship

```
toolbox:mr-ship        # full for a complex issue, short for a simple one
```

That runs the mechanical checks, the diff hygiene pass and `toolbox:mr-description`, then pushes and opens the PR/MR. The description **must** reference the issue key so the tracker links them.

Skill missing → push and open the PR by hand (`gh pr create` / `glab mr create`) with the key in the body.

## Step 7 — Move the issue to In Review

Adapter step. Set the in-review state and post the PR/MR URL back on the issue.

## Step 8 — Report

Five lines, no recap prose:

```
<KEY> <title>
branch    <branch>  (worktree <path>)
verdict   simple | complex — <deciding criterion>
PR        <url>
state     In Review
```

Then run `toolbox:issues-candidate` if the build surfaced anything worth filing.

---

## Failure handling

Any step failing stops the flow and says which step and why — never continue to the next state transition on a failed one. Specifically: don't mark In Review without a PR URL, and don't mark In Progress without a branch.
