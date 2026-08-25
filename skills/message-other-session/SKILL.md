---
name: message-other-session
description: Use when another concurrent Claude session needs to know something decided in this one before it redoes, undoes, or re-flags that work — a decision that contradicts a written spec, code that looks dead but is intentional, or a branch whose history moved under it. Triggers - /message-other-session, "dis-le à l'autre session", "tell the other session", "the mr-ship session needs to know", "préviens la session qui roule X".
---

# message-other-session

## Overview

Sends one scoped handoff message to a named peer session, after showing it to the user for approval.

**Core insight:** Concurrent sessions on the same branch fail in one specific way — the second session re-derives context the first one already settled, and "fixes" a deliberate decision back to the obvious-looking version. The cure is not a status report. It is the short list of things that, if unknown, cause rework. Everything else is noise the other session has to triage, which is the cost this skill exists to avoid.

## Steps

1. **Resolve targets.** Call `ListAgents`. Get the current branch (`git branch --show-current`). Session names are truncated branch slugs, so highlight the peers whose name matches the current branch, and list the rest below them. When no name matches, list every peer with no ranking.
2. **Gather content.** Take the subject the user named. Add only what passes the inclusion test below. Sources: this conversation, `git log <base>..HEAD`, and `git reflog` when the history was rewritten.
3. **Show the message.** Print it in full, exactly as it will be sent.
4. **Confirm.** Ask for target and text together: send / edit / cancel.
5. **Send.** `SendMessage` with the chosen name, then report that it was delivered.

## Inclusion test

A point goes in the message only if, without it, **the other session redoes, undoes, or re-flags settled work.**

Three families pass:

| Family | Example |
|---|---|
| A decision that contradicts a written spec | The ticket says the client camelCases the payload; the branch opted out via `stopPaths` and the types are snake_case |
| Code that looks dead but is intentional | Enum values and i18n keys typed against an unmerged upstream MR, inert until it lands |
| A branch state that moved under it | Rebased onto an updated base and force-pushed, so its local base is stale |

Everything else stays out. No recap of what this session accomplished, no "for your information" context, no restating what the other session can read in the diff.

## Message contract

The message is these parts, in this order:

```
Voici un message provenant d'une autre session.

Session: <name> [<ref>]  ·  branche: <branch>

<the named subject, developed enough to act on>

<one block per point that passed the inclusion test>

<branch-state warning, only when the history moved>
```

Body language follows the conversation. Identifiers, paths, SHAs, and field names verbatim.

## Rules

- **Never send before the user approves the text.** The message lands in a context the user is not watching; a wrong one costs more than the round trip.
- One target per invocation. Broadcasting puts a message two sessions out of three do not need into their context.
- Do not read the target session's context to guess what it already knows.

## Common mistakes

| Mistake | Fix |
|---|---|
| Sending a full session handoff | Apply the inclusion test to every point, including the one the user named |
| Sending to a same-named session on a different repo | Match on the branch, and show `[ref]` so two similar names stay distinguishable |
| Leading with what this session did | Lead with what the other session must not undo |
| Ranking peers when nothing matches the branch | An unranked list is honest; a wrong "probably this one" is not |
