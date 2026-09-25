---
name: start-issue
description: Take a tracker issue from "link pasted" to "PR open, issue in review" — reads the issue, creates the branch/worktree the tracker names, moves it to In Progress, builds it (directly if simple, plan-first if complex), opens the PR/MR, then moves it to In Review. Use whenever the user drops a bare issue link or key (Linear/GitHub/GitLab URL, `ABC-123`, `#42`) with no other instruction, or says "start this issue", "pick this up", "commence ce ticket". Do NOT use to file a new issue (that's `issues-candidate`) or to plan without building.
user-invocable: true
---

# Start issue

One entry point for "here's a ticket, go". A bare issue link is a full instruction: it means run every step below, in order, without asking between them.

**Principle:** the tracker is the source of truth for the branch name, the state names, and the scope. Never invent a branch name the tracker already owns, and never leave the issue's state lying about where the work actually is.

The build steps delegate to the other toolbox skills — this file is the spine, not a reimplementation.

---

## Step 0 — Resolve the input

Accept any of: a tracker URL, a bare key (`ABC-123`), or "the current branch's issue".

The session's own branch is the trunk (Step 2), so "the current branch" means a worktree's branch, not `git branch --show-current`:

```bash
git worktree list | grep -oiE "${TICKET_PREFIX:-[A-Z]{2,}}-[0-9]+" | tr '[:lower:]' '[:upper:]' | sort -u
```

More than one match → ask which; the session has no cwd to answer it for you.

Pick the tracker adapter from `trackers/<TRACKER>.md` (`TRACKER` in `PROFILE.md`, else inferred from the URL host). No adapter for the host → stop and say so; don't half-run the flow.

## Step 1 — Read the issue

Read the full issue: title, description, labels, state, estimate, priority, relations, **and its comments** — decisions often live only there. Follow `blockedBy` links far enough to know whether this issue is startable at all.

**A blocked issue does not start.** If an open blocker exists, say which one and stop. That is the only step that aborts the flow silently-free.

**An issue that already carries an MR/PR does not start from scratch.** Read the issue's attachments before Step 2: a PR/MR link there means work exists, and the tracker's own state may be lying about it. Check that PR's state with the host CLI:

- **Merged** → run the check in `trunk.md`. Work on the trunk → set the tracker's done state (Step 3's adapter, matched by the `completed` type), report with `verdict already shipped — <PR>, merged <date>`, and skip Steps 2-7. Work NOT on the trunk → the recovery in `trunk.md`, never a fresh build of the same spec.
- **Open** → resume: attach the worktree to that existing branch (the second shape in Step 2). Never cut a second worktree for the same issue.
- **Closed unmerged** → say so, then continue as a fresh start.

The stale worktree is not the signal — a worktree whose branch merged days ago looks exactly like one mid-build, and its branch being `[gone]` on the remote reads the same way. Measured 2026-09-21: an issue sat in progress six days after its MR merged, with that worktree still attached; the flow was one `git worktree add` from re-doing shipped work.

**An issue that ships no code does not get a worktree.** A design issue (the body says so, or its deliverable is a written decision) or one whose build was already split into a related issue has nothing left to branch for. Skip Steps 2 and 3, check each remaining acceptance criterion against live evidence, leave the state alone, and report which criteria are still open, one line each, in place of Step 8. Measured 2026-09-22 on STU-1587: In Review with no PR, its build split into STU-1632, and the one open criterion (a Sonarr hook firing on a real import) needed a check, not code. Only a close read of the body kept the flow from cutting a worktree for it.

**Backfill before building.** If the user's `CLAUDE.md`/`PROFILE.md` defines an issue standard (title form, description sections, required labels, estimate, priority), bring the issue up to it now, in one save, without asking. No standard defined → skip this, don't invent one.

**Draft rewrites through the environment's issue skill.** Both the backfill above and the re-scope below rewrite the issue's body, so they answer to whatever already owns issue prose here: check the available-skills list for a project- or user-level issue-creation skill (e.g. `linear-issue-creator`, a repo's own `new-ticket`) and let it shape the description — headings, forbidden sections, tone, and its provenance footer. It encodes team conventions this skill cannot know. None installed → follow the `CLAUDE.md` standard directly and end the body with `<sub>🤖 Rewritten with <code>/start-issue</code></sub>`, so a later reader can tell machine-drafted scope from the reporter's own words.

**Re-scope a stale issue.** If part of it already shipped, rewrite the description down to what actually remains and say the scope changed. Never implement a spec the codebase outgrew. Keep the reporter's framing where it still holds — a re-scope trims what shipped, it does not relitigate why the issue exists.

## Step 2 — Branch and worktree

Get the branch name **from the tracker** (adapter says how). Trackers own this — a hand-rolled name breaks their branch↔issue linking. No tracker-provided name → derive `<key-lowercased>-<kebab-title>` and say you derived it.

Two shapes, and the adapter says which one applies:

- **The tracker only names the branch** (Linear): create it locally.
  ```bash
  git worktree add -b <branch> .worktrees/<branch> origin/<default-branch>
  ```
- **The tracker creates the branch server-side** (GitHub `gh issue develop`, GitLab's branch API): the branch already exists on the remote and carries the link. **Attach** the worktree to it — creating a second local branch of the same name silently discards the link.
  ```bash
  git worktree add .worktrees/<branch> <branch>
  ```

Every task gets its own worktree, and the main checkout is never branch-switched.
Mechanics, the path contract and the rules for addressing one live in
`toolbox:use-git-worktree`; what follows is only what is specific to starting an issue.

### When the issue's premise lives in an unmerged PR

Cut the worktree from that PR's branch — you need its code to build on. But **open the PR against the trunk anyway**, and say the diff carries the base PR's commits until the base merges.

The alternative, basing the PR on the parent branch, is a stacked PR, and it fails in the direction that looks like success: when the base merges first, the child merges into a dead end, reports `MERGED`, and the trunk gets none of the work. See `trunk.md`. The stacked diff is cleaner to review; the failure is silent. Take the noise.

If a stacked base is chosen anyway — the base is huge, the reviewer asked for it — that is a decision, not a default, and it carries two obligations: retarget the child to the trunk the moment the base merges (`gh pr edit <n> --base <trunk>`), and Step 8 reports the base rather than staying quiet about it.

**The worktree holds the files, not the session.** Do not move the session's cwd into it — no `EnterWorktree`, no `cd`. Sessions are keyed by cwd, so a session that entered a worktree is filed under that path: `claude --resume` from the main checkout will not list it, which after a crash is indistinguishable from a session that never existed, and removing the worktree strands it for good.

So address the worktree explicitly for the rest of the flow — `git -C <path>`, `make -C <path>`, absolute paths for every read and write. Set `WT=$(pwd)/.worktrees/<branch>` once and use it. A bare `git` command now lands on the trunk, so confirm the worktree before the first edit, and never on `pwd`:

```bash
git -C "$WT" branch --show-current   # must print <branch>
```

## Step 3 — Move the issue to In Progress

Adapter step. Set the in-progress state and assign the issue to the user if it's unassigned. Do this **after** the worktree exists, so the tracker never claims work that has no branch.

Not every tracker has workflow states — GitHub and GitLab issues are only open/closed, and the state lives in a Project field or a scoped label, or nowhere. The adapter says which mechanism the repo actually uses; when it has none, assignment is the whole signal and the Step 8 report says so. Never fake a transition, and never close an issue to mean "moved on".

## Step 4 — Triage: simple or complex

**Check for a shaping bundle first.** Use the issue key already resolved in Step 0 — not `git branch --show-current`, which Step 2 already established prints the trunk here, not the worktree's branch.

```bash
BUNDLE="${SHAPING_DIR}/<KEY>.md"
[ -n "$SHAPING_DIR" ] && [ -f "$BUNDLE" ] && cat "$BUNDLE"
```

- **Bundle found:** use its `classification` field instead of re-deriving simple/complex below. `trivial`/`medium` → fall through to the criteria below as normal. `large` → this issue is expected to already be one of `toolbox:decompose`'s sub-tickets (created with a parent link) — plan it directly via `toolbox:plan`, skipping the criteria below. If it's marked `large` but carries no parent link, say so explicitly — decomposition may not have happened yet, and planning it flat risks the exact problem shaping exists to avoid.
- **No bundle:** the criteria below decide as they do today, with one addition to the Complex list: the issue body lists multiple distinct deliverables and has no parent ticket → recommend running `toolbox:shape` before planning, rather than silently planning a ticket that should have been decomposed first.

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

## Step 4.5 — Check what else is already in flight

Step 4 named the files this issue will touch. Before writing to any of them, find out who else
is already writing to them. The tracker's open issues and the host's open PRs both answer it,
and neither is Step 1's attachment check, which only covers *this* issue.

```bash
for n in $(gh pr list --state open --json number -q '.[].number'); do   # glab mr list
  gh pr view "$n" --json number,headRefName,files \
    -q '[.number, .headRefName, (.files[].path)] | @tsv'
done
```

Search the tracker for open issues naming the same file or subsystem (the adapter's search call).
A hit means one of three things, and the flow continues either way; say which:

- **Already fixed there.** Drop that part of the scope, say so, and link the other issue. Do not
  re-fix it: two PRs fixing one defect conflict on the exact lines both changed.
- **Same file, different lines.** Build as planned, and expect a rebase rather than a clean merge.
- **Same lines, both open.** Propose a merge order instead of resolving it unilaterally, and tell
  the other session (`toolbox:message-other-session`). Work already merged is rebased onto, never
  rewritten.

Measured 2026-09-22: three open PRs edited one 40-line script the same afternoon, two of them on
the same lines, and one carried a flag the other author had not found. Nothing surfaced the
overlap until `toolbox:issues-candidate` deduped against the tracker at the very end, after the PR
body was written. Finding it here costs one command; finding it at Step 6 costs a rewritten diff.

Cheap enough to run on a simple issue too. Skip it only when the diff creates new files and
touches nothing that already exists.

## Step 5 — Build

Small, logical commits — one per change, not one per session. Commit as you go, not in a pile at the end.

Scope discipline: every changed line traces to the issue. Findings outside it go to `toolbox:issues-candidate` at the end, not into this diff.

## Step 6 — Ship

```
toolbox:mr-ship        # full for a complex issue, short for a simple one
```

That runs the mechanical checks, the diff hygiene pass and `toolbox:create-or-update-mr`, then pushes and opens the PR/MR. The description **must** carry the issue key behind the magic word of the link type chosen below. A bare key links nothing.

Skill missing → push and open the PR by hand (`gh pr create` / `glab mr create`) with that same line in the body.

### Choose the link type

Decide from the issue's proof criteria, not from the diff:

| Type | When |
| -- | -- |
| **Resolves** | This is the issue's last open PR, and merging it satisfies every proof criterion the issue states (tests, CI). |
| **Contributes** | The issue stays open after merge: its proof needs a post-merge run or a calendar gate (a due date), a manual or host step remains, or another PR for the same issue is still open. |
| **Related** | The PR advances none of the issue's proof criteria: a fix found along the way. |

Unsure between Resolves and Contributes → Contributes. A wrong Contributes costs one manual close; a wrong Resolves closes an unproven issue at merge, and nothing reopens it.

The key goes in the PR/MR **title** only for Resolves. The adapter gives the words for each type.

## Step 7 — Move the issue to In Review

Adapter step. Set the in-review state and link the PR/MR back on the issue, through the tracker's native link (the Step 6 link-type line, a Linear attachment), not just a comment.

**Re-read the state before reporting it.** A tracker integration reacts to the PR opening on its own schedule and can overwrite the state you just set: Linear's GitHub integration moved two of seven issues back to In Progress after the save had returned In Review (2026-09-22). The save's response is not the final state. Read the issue again and set In Review once more if it moved.

## Step 8 — Report

Seven lines, no recap prose:

```
<KEY> <title>
branch    <branch>  (worktree <path>)
base      <base>  [not the trunk — see below]
verdict   simple | complex — <deciding criterion>
link      Resolves | Contributes | Related: <deciding criterion>
PR        <url>
state     <as read back from the tracker after Step 7>
```

`state` is the tracker's answer to the last read, never the state the flow set. Anything but In Review is the finding: report it as read.

`base` is read back from the PR, not from what Step 2 intended:

```bash
gh pr view <n> --json baseRefName -q .baseRefName    # glab mr view <n> -F json | jq -r .target_branch
```

Base is not the trunk → say that merging this PR will not put the work on the trunk, and name the retarget. Do not report `state In Review` as if the flow were clean; the stack is the finding.

**If a merge happened while this flow was running** — the user merged the PR mid-session, or the flow ran under `start-milestone` — run the check in `trunk.md` before reporting anything as shipped, and report its verdict. A PR URL is evidence that a PR exists; it is not evidence that the trunk has the work.

Then run `toolbox:issues-candidate` if the build surfaced anything worth filing.

---

## Failure handling

Any step failing stops the flow and says which step and why — never continue to the next state transition on a failed one. Specifically: don't mark In Review without a PR URL, don't mark In Progress without a branch, and don't report a shipped state without the trunk check in `trunk.md`.
