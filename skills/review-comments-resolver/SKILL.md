---
name: review-comments-resolver
description: Use to resolve unaddressed review comments on a PR/MR — from human reviewers and bots (CodeRabbit, Cursor Bugbot). Triggers - "fix review comments", "resolve PR/MR feedback", "handle the bot review", "fix coderabbit/bugbot findings", or to process pending code review.
user-invocable: true
---

# Review Comments Resolver

Process all unresolved review comments on a PR/MR. **Collect every source → triage together (role-weighted) → fix approved → verify → reply + resolve.** This file is the method (identical on every host); the exact API calls live in the matching provider file.

```bash
case "$(git remote get-url origin)" in *github*) HOST=github;; *gitlab*) HOST=gitlab;; esac
# Read providers/$HOST.md — it has the full worked flow for: detect PR/MR · list inline+general
# comments · await in-progress bots · reply to a thread · resolve a thread.
```
For every step below that says *(see provider file)*, use the calls in `providers/$HOST.md`.

## When to Use
- `/review-comments-resolver` or `… <PR/MR_NUMBER>`
- Asked to fix review comments / handle bot or human findings

---

## Step 1 — Detect the PR/MR
Detect the PR/MR for the current branch *(see provider file)*. If none, STOP — ask for the number.

---

## Step 2 — Wait for in-progress bot reviews

A review in flight = incomplete findings. Detect active bots and poll (every 30s, ~5–10 min max) until done, then proceed. If no bots are present, skip.

- **CodeRabbit** — done when its summary comment appears (body contains `summarize by coderabbit.ai`).
- **Cursor Bugbot** — has an in-progress signal per host.

The author patterns and the await signals differ per host *(see provider file)*.

---

## Step 3 — Collect all unresolved comments

Collect three categories, **including both inline (has a file/line) and general (no position) comments** — humans often leave feedback as general comments; missing those is a critical gap.

- **A. Human** — author is not a bot; resolvable & unresolved.
- **B. Bugbot** — Cursor bot author; inline; unresolved.
- **C. CodeRabbit** — CodeRabbit author; inline; unresolved. Also read its **summary comment** (don't treat as a finding) to pull nitpicks lacking an inline note (mark `[nitpick]`).

Capture per finding: file + line (or `(general comment)`), body, author, and the **thread/discussion id** (needed to reply + resolve in Step 8). If nothing unresolved → DONE, report all-clear.

---

## Step 4 — Analyse each finding (role-weighted)

**Read the actual code** at each finding (use the file reader, not `sed`/`cat`) and form an independent opinion. Source weight changes the default treatment:

| Source | Default treatment |
|--------|-------------------|
| 🤖 Bot (CodeRabbit / Bugbot) | Judge independently; dismiss false positives freely — bots flag patterns, not intent. |
| 👤 Peer | Read, judge, push back on style with rationale. Equal-level discussion. |
| 👤 Lead (domain owner) | Authoritative on their domain; clarify rather than silently dismiss. |
| 👤 Architect / CTO / project owner | Near-authoritative; don't dismiss without strong evidence; frame disagreement as a question. |
| 👤 Domain expert (backend/algorithm/product) | Authoritative on their domain, not on UI/style. |

**Configure the name→role mapping for your team** (e.g. in the repo's `CLAUDE.md`/`AGENTS.md`). Unknown human → treat as peer. If you have a `receiving-code-review` skill, apply its rigor (verify before agreeing *or* disagreeing).

**Recommendation per finding:**
- `✅ Fix now` — real issue, straightforward, belongs in this PR/MR
- `📋 Tracker issue` — valid but out of scope (refactor, broader test coverage, architectural)
- `🗑️ Dismiss` — false positive, already handled, or nitpick not worth the noise
- `❓ Clarify with reviewer` — high-weight human feedback you'd otherwise dismiss but whose intent may be load-bearing. **Draft a question instead of silently dismissing.** This avoids both failure modes: implementing senior feedback blindly, and silently ignoring it.

Be direct and opinionated — one-line reason, no hedging.

---

## Step 5 — Unified triage table

```
Found {N} unresolved comment(s) on #{id} "{title}":

1. ✅ Fix now — 👤 Alice (peer) — src/Foo.tsx:55
   Prefer early return to reduce nesting
   → Legit, cleaner

2. 🗑️ Dismiss — 🤖 CodeRabbit 🟡 — src/Foo.tsx:88
   Redundant type assertion
   → Already typed upstream, false positive

3. ❓ Clarify — 👤 Sam (CTO) — (general comment)
   "Should this go through the queue?"
   → I'd keep it sync; intent may differ — ask
```
Per finding: `{rec} — {icon + name (role)} {severity?} — {file:line | (general comment)}` / comment summary / `→` honest take.

Summary + `Default if you say "go": fix ✅, file 📋 in the tracker, dismiss 🗑️, draft questions for ❓.`

**STOP — wait for explicit confirmation.** `AskUserQuestion`: **Go** · **Fix all** · **Let me pick** · **Skip all**.

---

## Step 6 — Execute

**6A — Fix `✅`:** read the code (inline → file/line; general → infer the area, search if needed), apply the fix per repo conventions, report each.
**6B — `📋` tracker issues:** create via the tracker's CLI/MCP if available, else output a copy-paste-ready issue (title, finding, file:line, source, one-paragraph analysis, label).
**6C — `❓` clarify:** draft a non-adversarial question ("I read this as X because [code reason] — was your intent X or Y? Happy to do either."). Show the user; they choose **send as-is** / **edit + send** / **override→fix** / **override→dismiss**. Post as a thread reply; **do not resolve** (keep open for the reply). Never silently dismiss a `❓`.

---

## Step 7 — Verify
Run the repo's own checks on touched files (detect: `npm run check`/`type-check`/test, `ruff`/`mypy`/`pytest`, etc.). If a fix breaks a check: correct, re-run once; if still failing, report and let the user decide. **Never commit broken code.**

---

## Step 8 — Reply + resolve processed threads

**8A — comment FIRST on every `🗑️ Dismiss` and `📋 Tracker` thread**, before resolving — reviewers deserve the rationale; silent resolution is disrespectful and unauditable.
- Dismiss (already fixed) — "Already fixed — {what changed}."
- Dismiss (false positive) — "False positive — {why it doesn't apply}."
- Dismiss (nitpick) — "Nitpick — {why not worth addressing}."
- Tracker — "Deferred to {ISSUE}: out of scope for this PR/MR — {what the fix involves}."

**8B — resolve** every processed thread (`✅` fixed, `🗑️` triaged+commented, `📋` captured+commented), across all sources. **Do NOT resolve `❓ Clarify` threads** — they stay open for the reviewer's reply. Don't resolve threads not processed this session.

Report: `Resolved {N} thread(s) ({X} CodeRabbit, {Y} Bugbot, {Z} human).`

---

## Provider mechanics

The exact API calls — detect PR/MR, list inline + general comments, await in-progress bots, reply to a thread, resolve a thread — live in the provider file for the detected host:

- **`providers/github.md`** — `gh` + GraphQL review threads (resolution is GraphQL-only; REST comment id ≠ thread id).
- **`providers/gitlab.md`** — `glab` REST notes/discussions (use `/notes`, not `/discussions`).

Read the one matching `$HOST` and use its worked flow wherever a step says *(see provider file)*.

---

## Error handling
| Condition | Action |
|-----------|--------|
| No PR/MR for branch | STOP — provide the number |
| CLI not authenticated | STOP — `gh auth login` / `glab auth login` |
| No unresolved comments | DONE — all-clear |
| Bot poll timeout | WARN — proceed with what's found so far |
| Ambiguous human comment | ASK — clarify before fixing |
| Verify fails after retry | WARN — report, don't commit |
