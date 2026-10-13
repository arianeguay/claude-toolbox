---
name: can-i-close
description: Use when the user asks whether the current session can be closed — checks what closing would lose or leave broken (uncommitted or unpushed work, running background jobs, temporary state on hosts, a verification the session promised to run, a handed-off command never confirmed) and answers yes or no with the one action per blocker. Triggers - /can-i-close, "je peux fermer ?", "can I close this", "on peut fermer la conversation ?", "is it safe to close".
user-invocable: true
---

# can-i-close

Answer one question: **does closing this session lose something or leave something broken?**

Unfinished is not a blocker. Work that is written down somewhere that outlives the session (a tracker issue, a pushed branch, an open PR, a memory) survives the close. A blocker is something that exists only in this session, or a state the session created and has not undone.

## Step 1 — Gather

Sources, in order: this conversation, then the live state it touched. Re-check live state. Never rely on what the conversation last said about it: a PR said to be open may be merged, a service said to be stopped may be back up.

## Step 2 — Check each row

| # | Check | How | Blocker when |
|---|---|---|---|
| 1 | **Uncommitted or unpushed work** | For every repo and worktree the session wrote to: `git -C <wt> status --porcelain`, `git -C <wt> log @{u}..` (no upstream counts as unpushed) | Any output |
| 2 | **Running background work** | Background shells, background agents, workflows, monitors started by this session | Still running and its result is not written anywhere outside the session |
| 3 | **Temporary state on a host** | Anything the session set up "for now": a stopped service or container, a paused health check or maintenance window, a temp sudoers or firewall rule, a scratch file outside the scratchpad, a machine powered on by hand | Not undone, and nothing will undo it on its own |
| 4 | **A promised check** | Lines like "I'll verify after the deploy", "next cron tick", "once you run it, tell me" | The check has not run and its outcome is not recorded where someone will see it |
| 5 | **A handed-off command** | Commands given to the user to run | The user has not reported the result, and the session was going to verify or record it |
| 6 | **Tracker state** | Issues this session moved or promised to close | In Progress or In Review with no PR or comment that explains the state |

A row that cannot be checked (a host down, an auth failure) is reported as `unverified`, never as clear.

## Step 3 — Verdict

One of three:

| Verdict | When |
|---|---|
| `YES` | No blocker |
| `YES, AFTER` | 1-3 blockers, each fixable in under 2 minutes. Fix the ones the session can fix itself, then re-check. List the rest for the user |
| `NOT YET` | A blocker that takes real work, or one the user must decide |

## Step 4 — Emit

```
<VERDICT>: <one reason, under 10 words>

BLOCKERS (n)
1. <what would be lost or left broken>: <the one action that clears it>

SURVIVES THE CLOSE (n)
1. <open item>: <where it is written down>

UNVERIFIED (n)
1. <row>: <why it could not be checked>
```

- Drop empty sections. A `YES` with nothing else is a one-line answer.
- `SURVIVES THE CLOSE` is at most 3 items, and only items the user might worry about: an open PR, a waiting issue, a pending deploy. It exists to say "this is safe", not to recap.
- One fact per line, under about 90 characters.
- No CAPTURE line and no summary. Those are `toolbox:adhd-summary` and `toolbox:what-did-we-learn`. If neither ran since the last real change, add one line: `Not captured yet: run /toolbox:adhd-summary before closing.`

## Don't

- Don't call something a blocker because it is unfinished. Recorded means safe.
- Don't trust the conversation's memory of a state. Read the state.
- Don't fix a blocker that changes something outside the session's own mess (a merge, a deploy, a delete) without asking. Undoing the session's own temporary state is in scope.
