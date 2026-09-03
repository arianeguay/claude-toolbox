---
name: adhd-summary
description: Compress a finished task into a merge/don't-merge verdict, the few things that actually need the human, and the issues worth filing. Use when the user says "/adhd-summary", "summarize this", "résume-moi ça", "what do I need to know", "can I merge this" — or at the end of a task when the user is running several sessions at once and will not read a long report. Produces a fixed, skimmable block, never prose.
user-invocable: true
---

# ADHD Summary

Hand back the two or three facts that decide what the reader does with this work in the
next 60 seconds. Nothing else.

**Who this is for:** someone with several sessions open at once, late in the day, who
merges fast and will not read a PR body. Assume they have forgotten the task. Assume they
read the first line and the bold labels, and nothing in between.

**Core principle:** the summary is not a shorter report — it is a *decision*. If it does
not change what they do next, it does not go in.

---

## When to use

- `/adhd-summary`, "summarize this", "résume", "what do I need to know", "can I merge this"
- End of a task, right after a PR/MR is opened
- The user comes back to a session that ran while they were elsewhere

**Don't use** mid-task — there is no verdict to give yet. Use `toolbox:am-i-stuck` instead.

---

## Step 1 — Gather

In this order, stopping as soon as you have the verdict:

1. **This conversation** — if the work happened here, it is the best source.
2. **The branch** — if it didn't:

```bash
BASE=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git log --oneline "$BASE"..HEAD | head -20
git diff "$BASE"...HEAD --stat
```

3. **The PR/MR** — `gh pr view` / `glab mr view`, plus CI state.

You need four things and only four: what is true now that wasn't before, whether the
change was actually verified, what a merge would make irreversible, and what got left out.

---

## Step 2 — Decide the verdict

One of exactly three. Pick with this table:

| Verdict | When |
|---|---|
| `MERGE IT` | Change does what it claims, it was verified by something that ran, nothing left needs a human decision |
| `DON'T MERGE YET` | Anything was left unverified, a claim in the PR body is unproven, or a decision is open |
| `YOUR CALL` | The work is sound, but it encodes a choice only the user can make (a trade-off, a cost, a convention) |

**Unverified means don't merge.** The reader merges fast; "I believe it works" is the
failure mode this skill exists to catch. If the tests weren't run, say so as the verdict
reason — never as a footnote.

---

## Step 3 — Emit the block

Fixed shape. Do not improvise a nicer one.

```
<VERDICT> — <the one reason, under 10 words>

<One line: what is true now that wasn't before. Plain words.>
<One line: how it was verified, or "not verified".>

NEEDS YOU (n)
1. <imperative action> — <why, one line>
2. ...

FILE THESE (n)
1. <issue title> — <why it matters, one line>
2. ...

Skipped <n> things that don't need you.
```

Rules for the block:

- **Two lines of summary. Never three.** However big the task was.
- **Max 3 items** under each heading. If there are more, the bar was too low — re-filter.
- **One fact per line**, under ~90 characters. No sentence spans two lines.
- **Drop empty sections entirely.** `NEEDS YOU (0)` is noise; absence says it already.
- **No ticket key alone.** `STU-1147` means nothing at 8PM — write `STU-1147 (the erosion
  measurement one)`.
- **No vocabulary the session invented.** Name the thing in words that worked before this
  task started.
- **No mechanism.** Why it works, how it was built, what was considered — all cut. The
  verdict reason is the only reasoning that survives.
- **Keep the skipped count.** It proves the filter ran and stops the reader wondering what
  was hidden. Say `Skipped nothing.` when there was nothing.

---

## Step 4 — What earns a line

**NEEDS YOU** — only these four:

1. Merging makes it irreversible (data, migration, published record, deploy).
2. A decision only the user can make is still open.
3. A claim in the PR body isn't backed by something that ran.
4. It will collide with another session running right now.

**FILE THESE** — work the user would regret losing: a deferral made during the task, a bug
found and left alone, a gap the change exposes. Each gets a title they'd recognise cold and
one line of why. **Do not file them here** — offer `toolbox:issues-candidate`, which has the
tracker metadata and the approval flow.

Before listing an item, check it is still open. Something fixed live during this same
session — a config edited on a remote host, a follow-up applied while gathering context —
is not a follow-up; it belongs in the two-line summary or nowhere, never in FILE THESE
worded as both done and pending in the same breath.

Everything else — refactors done, tests added, files touched, options weighed, things that
went fine — is skipped. It goes in the count, not on the page.

---

## Step 5 — Offer exactly one next action

One line, after the block. Pick the one the verdict implies:

- `MERGE IT` → "Merge: `gh pr merge <n> --squash`"
- `DON'T MERGE YET` → the single command that closes the gap ("Run `make test` — 30s")
- `YOUR CALL` → the one question, asked once, answerable in a word
- Issues listed → "File them: `/toolbox:issues-candidate`"

Never offer two. Never end with "let me know if you want more detail" — if detail matters,
it was a line in the block.

---

## Example

```
DON'T MERGE YET — the suite never ran on this branch.

Bake-off runs now say when a reviewer was missing a tool, instead of failing.
Not verified: tests unrun since the last commit.

NEEDS YOU (1)
1. Decide: annotate or fail? Shipped as annotate — a failing gate would block comparisons.

FILE THESE (1)
1. qa_coverage has the same blind spot — left alone deliberately, its reader has no tools.

Skipped 6 things that don't need you.

Next: `make test` (about 30s), then merge.
```

---

## Don't

- Don't open with what you're about to do, or close with a recap
- Don't explain the implementation, however interesting it was
- Don't hedge a verdict — "probably fine" is `DON'T MERGE YET`
- Don't pad a section to look thorough; an empty one is a good outcome
- Don't list what went well
- Don't use emoji, and don't use more than one marker style
- Don't file issues from this skill
- Don't produce this mid-task
