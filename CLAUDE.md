# CLAUDE.md (Personal — Portable)

Instance-agnostic working style. No employer/company/project specifics — those live in
each job's own global or project `CLAUDE.md`. This file is a template: copy it into
`~/.claude/CLAUDE.md` on a new machine (or merge it into an existing one), then layer
company-specific context on top.

## Collaboration Model

I give direction (a ticket, a bug report, a priority). You do the work — code, tests,
lint, commits. **Act, don't ask for permission** on reversible, expected steps: running
tests, linting, type-checking, committing, pushing to a branch you're already working on.
If something fails, fix and retry without asking first.

Only stop and ask for: irreversible/destructive actions (force-push, history rewrite on a
shared branch, deleting something not yours), major architectural decisions, or a genuinely
ambiguous requirement — and even then, state your assumption and let me correct it rather
than opening with a question when a reasonable default exists.

## Code Philosophy

- **Simplicity first.** Minimum code that solves the problem. No speculative abstraction,
  no unrequested config/flexibility, no error handling for scenarios that can't happen.
  If it could be a third the size, rewrite it — ask "would a senior engineer call this
  overcomplicated?"
- **Surgical changes.** Touch only what the task requires. Don't refactor adjacent code,
  don't restyle to your own taste — match existing convention even if you'd choose
  differently. Every changed line should trace to the request.
- **Remove over add, fix the root cause.** Default bias is deletion, not accumulation.
  Disproportionate machinery for a small win is a sign the *approach* is wrong, not that it
  needs tidying. When you see defensive/validation/dedup scaffolding, ask "why does this
  need to exist?" — if the answer is "to paper over X," undo X; don't harden the band-aid.
- **Comments: default to none.** Write one only when the code cannot say the *why* itself
  — a hidden constraint, a non-obvious invariant, a workaround for a specific bug. Never
  explain *what* the code does; well-named identifiers already do that. One clause per
  fact, no connective prose stitching multiple facts into a paragraph.

## Git Workflow

- Prefer a **git worktree** over branch-switching in the main checkout when starting
  isolated feature work — main checkout stays on the trunk branch.
- **Commit small and often** — one logical change per commit (new function, bug fix,
  refactor, test, i18n change). Don't batch unrelated fixes into one commit.
- **Merging the trunk/parent branch into a feature branch:** use the `merge-parent` skill
  in this repo — it runs a mechanical anti-drop check on every conflict resolution so a
  "trivial-looking" resolve can't silently revert already-merged work.
- Commit trailer: `Co-Authored-By: <model name> <noreply@anthropic.com>` — derive the
  name from the model actually running the session (read it from the session context),
  never hardcode a version string that goes stale across model updates.

## Styling Default

Default to **Tailwind** over raw CSS/SCSS for any new project or component, even before
checking whether the specific repo has a stated convention. Don't migrate a repo's
existing CSS/SCSS unilaterally — but new styling in that repo still defaults to Tailwind
unless told otherwise.

## Presenting Trade-offs

When there are 2+ options to choose between (architecture picks, "swap A for B", design
decisions), use a side-by-side pros/cons layout, not narrative paragraphs:

```
**Option A**
- ✅ <pro>
- ❌ <con — and how to mitigate, if cheap>

**Option B**
- ✅ <pro>
- ❌ <con>

**My take:** <one-line recommendation + why>
```

One fact per bullet line, always close with a recommendation — don't leave synthesis to
the reader. (Doesn't apply to a single-finding go/skip approval — that stays one line.)

## Language

Chat replies in French (native thinking language). Everything that leaves the chat —
code, comments, commit messages, PR/MR descriptions, docs, READMEs, tickets, skills,
config files, any file another person might read — is **English**, no exceptions. Don't
rely on catching it on review; default to English proactively for any written artifact.

## Decision-Making Style

I'm AuDHD. Two things that help:

1. **Externalize criteria, don't rely on "feel."** When proposing how to split work, cut
   scope, or classify effort, list the concrete criteria so I can verify against them
   rather than intuit whether it's right.
2. **Don't interrupt hyperfocus with unsolicited "are you sure" checks.** If I'm clearly
   executing on a plan, stay out of the way. Surface concerns before I start or after a
   natural checkpoint, not mid-flow.
