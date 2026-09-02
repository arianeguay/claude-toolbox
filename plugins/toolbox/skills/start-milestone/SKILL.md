---
name: start-milestone
description: Take a whole tracker milestone from "link pasted" to "every open issue shipped" — enumerates the open issues, orders them by what their verification costs, runs each through start-issue, sequences the merges, and closes with one adhd-summary for the set. Use when the user drops a milestone/project link or says "do every open task in this milestone", "clear this milestone", "fais tout le milestone". Do NOT use for a single issue (that's `start-issue`) or to plan a milestone without building it.
user-invocable: true
---

# Start milestone

`start-issue` for one ticket, N times, plus the four things that only exist when the
tickets are a *set*: what order they run in, what starts in the background first, what
order they merge in, and one summary at the end instead of N.

**Principle:** the milestone is a batch, not a queue. The cheap issues are the deliverable
you can hand back today; the expensive one decides when the batch is done. Those are
different jobs, and running them in list order does neither well.

---

## Step 0 — Resolve the milestone and enumerate its open issues

Accept a milestone URL, a project URL plus a milestone name, or a bare name.

Pick the adapter from `../start-issue/trackers/<TRACKER>.md` — everything about reading an
issue, naming a branch and moving state lives there and is not repeated here. The one
query this skill adds is enumeration:

| Tracker | Enumerate the milestone's open issues |
| -- | -- |
| Linear | `list_issues` with `project:` + `state:` per open type, then filter on `projectMilestone.name` client-side. **There is no milestone filter and results paginate** — a single unfiltered call silently returns the first page and looks complete. |
| GitHub | `gh issue list --milestone "<name>" --state open --json number,title,labels,url` |
| GitLab | `glab issue list --milestone "<name>" --state opened` |

**Enumerate by state, not by scrolling.** Ask for each open state the tracker has
(`backlog`, `unstarted`, `started`) and concatenate. A milestone read off one page of a
mixed list is how an issue gets left behind, and nothing later notices.

Print the list before touching anything: key, title, estimate, labels, priority. If it is
empty, say so and stop — do not go looking for adjacent work.

## Step 1 — Order them, on stated criteria

Never "I'll start with the easy one". Score each issue on three axes the user can check:

| Axis | Cheap end | Expensive end |
| -- | -- | -- |
| **Verification cost** | a test run, a lint, a local replay | a paid live run, a real API call, a human read |
| **Wall clock** | minutes | hours, unattended |
| **Blast radius** | one module | shared files every sibling also edits |

Two rules fall out, and they pull in opposite directions on purpose:

1. **Deliver cheap-and-verifiable first.** They are done and mergeable while the rest is
   still running, so a session that gets interrupted has still shipped something.
2. **Launch the longest unattended run as early as it can start.** It is the critical
   path; every minute it is not running is a minute added to the end of the batch.

So the shape of a good batch is: *start the long paid run in the background, then build the
cheap issues while it burns.* Say the order and the criterion that produced it, in a table,
before starting.

**Dependencies outrank cost.** If one issue's answer changes another's scope, the answer
comes first even if it is the expensive one — and say so, because it means the cheap work
waits.

## Step 2 — Should any of these be one PR?

The user usually asks. Answer on the artifact, not on the topic:

**Merge into one PR when** the issues edit the *same paragraph* of the same file, or one's
verification is literally the other's diff. Two issues that would conflict with themselves
are one change filed twice.

**Keep separate** otherwise — the default, and it was right for every issue in the session
this skill was written from. One issue = one shippable change, the tracker's issue↔PR link
stays intact, and same-file conflicts in *different* sections are cheaper to rebase than a
merged PR is to review. Touching the same file is not a reason to merge; touching the same
sentence is.

State the decision once, per pair, with the criterion. Do not re-litigate it later.

## Step 3 — Run each issue through `start-issue`

Invoke `toolbox:start-issue` per issue, in the Step 1 order. It owns the worktree, the
state transitions, the build and the PR. Two milestone-level additions:

- **The worktrees are siblings and the session is not in any of them.** Address every one
  explicitly (`git -C <wt>`, `make -C <wt>`, absolute paths). With several open at once,
  a bare `git` command is a coin flip.
- **Do not wait on the long run.** Its worktree exists and its measurement is burning;
  come back to write it up when it lands.

## Step 4 — Sequence the merges

Merging N sibling PRs is not N merges. They branched from the same commit, so every one
after the first is behind.

For each PR after the first, in order:

```bash
git -C <wt> fetch -q origin && git -C <wt> rebase origin/<default>
<the project's test command, in that worktree>     # the rebase is a merge; prove it
git -C <wt> push --force-with-lease
```

then wait for the check to go green before merging it. Rebasing all of them up front does
not work — each merge moves the base again.

**Prove the rebase, do not assume it.** Two changes that both apply cleanly can still
disagree; the test run after the rebase is the only thing that says otherwise.

**Prove the merge too.** This is the one place in the toolbox that observes a merge, so it
owns the assertion — run the check in `../start-issue/trunk.md` after each merge, before
moving on to the next:

```bash
git -C <wt> fetch -q origin
git -C <wt> merge-base --is-ancestor HEAD "origin/<default>"   # exit 0 = the trunk has it
```

A PR reporting `MERGED` merged into *its base*, which in a batch is not always the trunk.
Failing it stops the sequence — the next rebase would be onto a trunk that is missing the
work you just merged, and the drop would look like a clean rebase. The recovery is in
`trunk.md`; it is a cherry-pick onto the trunk, never a force-push of the merged branch.

Delete the worktree before the branch — `git branch -D` refuses a branch a worktree holds,
and the error arrives after the merge has already happened, which reads like a failed merge.

## Step 5 — Close the set

Move every issue to its done state — **only the ones Step 4 saw land on the trunk.** An
issue whose commits are not on the trunk is not done however its PR reads; leave it where
it is, name it in the summary, and carry the recovery there.

Then run `toolbox:adhd-summary` **once for the milestone**, not once per issue. The verdict the user needs is about the batch: what
merged, what still needs them, what got filed.

If anything was left undone, say which and why, in the summary — a milestone reported as
finished with one issue quietly still open is the failure this skill exists to prevent.

---

## Long unattended runs

The expensive issue is usually a paid measurement, and it is where a batch dies. Six things,
all of them learned the hard way:

- **Detach it from the session.** `setsid nohup <cmd> > <log> 2>&1 < /dev/null &`. A
  backgrounded job that the session owns dies with the session, hours in, having written
  nothing.
- **Smoke it small first.** One item, one repeat, output to a throwaway path. An invocation
  error found in 3 minutes beats one found in 3 hours.
- **Send it to a fresh output path** when a resumable trace exists beside the old one.
  A harness that reuses "runs already paid for" will happily reuse the runs you are
  re-measuring *because* they are suspect.
- **Keep the machine awake**, and check the wall power, not just the setting:
  ```bash
  systemd-inhibit --what=idle:sleep:handle-lid-switch:handle-suspend-key \
    --who=<job> --why=<reason> --mode=block \
    bash -c 'while pgrep -f <job-pattern> >/dev/null; do sleep 60; done'
  ```
  Run it detached; it releases itself when the job exits. It does not cover a flat
  battery — read `/sys/class/power_supply/A*/online` and say so out loud.
- **A rate measured across a sleep is not a rate.** Mark the count and the clock at a known
  awake moment and re-derive; an estimate taken across a suspend was 3x pessimistic in the
  session this was written from.
- **Never let a waiter match itself.** `pgrep -f "foo.py"` inside a shell whose own command
  line contains `foo.py` matches that shell, so the loop waits forever and the chained work
  never starts. Match on a marker file the job writes, or on a pattern that cannot appear in
  the waiter. `pkill -f` has the same trap and kills the caller.

## Traps

- **`cd` persists between calls.** A compound `cd X && ...` leaves the shell in `X` for
  every later call, so the next edit lands in the wrong checkout. It fails loudly when a
  string does not match, and silently when it does. Use absolute paths.
- **The main checkout is usually behind.** Branch worktrees off `origin/<default>` after a
  fetch, never off the local branch.
- **An issue's own label can be wrong, and measuring it is part of the work.** One issue in
  the source session was filed `local` pending a question its own description posed; the
  answer was in the code, and it shipped as `web`. Backfill the label when the answer lands.
- **A measurement that holds is a result.** Re-running something to check it was not
  contaminated and finding the same number is the finding, not a wasted run. Record both
  readings; do not overwrite the old one.
