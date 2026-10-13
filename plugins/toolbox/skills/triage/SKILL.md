---
name: triage
description: Use to work through a tracker's triage queue — reads every issue waiting in triage, runs a one-minute check on each, backfills missing metadata, and gives a keep / fix now / drop verdict per issue in one table; on approval it moves kept issues out of triage, fixes the small ones, and cancels the rest with a signed reason. Triggers - /triage, "on passe à travers le triage", "go through triage", "clear the triage queue", "trie le triage", a screenshot of the Linear Triage view.
user-invocable: true
---

# triage

Empty the triage queue in one pass: **read → check → verdict table → wait for approval → act.**

An issue in triage was filed by someone (often a past session) who has not yet decided it deserves a row in the backlog. This skill makes that decision with evidence, not on the title.

## Step 1 — List the queue

Linear: `list_issues state: "triage"` (all teams unless the user names one), then `get_issue includeRelations: true` on each. Read the full description; the title alone decides nothing.

GitHub/GitLab have no triage state: use open issues carrying a `triage`/`needs-triage` label, else ask which view the user means.

A screenshot of the queue gives the keys; still fetch each issue, since the screenshot shows titles only.

## Step 2 — Check each issue (one minute each)

Every verdict cites a check that ran in this step. Run them in parallel.

1. **Still true?** Run the cheapest command that would show the problem is gone: read the file or line the issue names on the trunk (`git fetch` first), the version on the host, the config value. Refuted means drop or rewrite it smaller.
2. **Already covered?** Apply the `Already filed` and `Premise contradicted` filters from `issues-candidate` Step 3: search the tracker by title words and by each entity the issue names.
3. **Blockers' state.** For each `blockedBy`, read its status. A blocker already done makes the issue ready; one canceled makes the issue's premise suspect.
4. **Worth a row?** Apply the remaining `issues-candidate` Step 3 filters (no trigger, speculative, taste-only refactor). An issue that waits on an event with no date (a future incident, a purchase, "the next time X happens") is speculative unless that event already has a tracker row it can hang off.
5. **Metadata gaps.** Compare against the user's issue conventions (`CLAUDE.md`, global rules): estimate, priority, project, required label groups, `blockedBy` ordering, due date for a calendar gate. Note each gap; it gets filled in Step 5, not reported as a problem.
6. **Automation hazards.** If the issue carries a label that hands it to an unattended runner, check the runner can actually finish it: the repo is on the runner's allowlist, its proof can run where the runner runs, and it is not waiting on an undated event (the runner would pick it every night and find nothing to do). Fails → remove the label or add the blocker that makes it wait.

## Step 3 — Verdict per issue

| Verdict | When | Action on go |
|---|---|---|
| `🔧 Fix now` | Under ~5 minutes, in scope of one repo or one host, no decision pending | Build it in this session through `start-issue` (worktree, PR, In Review) |
| `📋 Keep → Todo` | Ready to start: no open blocker, metadata complete after backfill | Move to Todo |
| `📋 Keep → Backlog` | Real, but blocked or low priority | Move to Backlog |
| `🔁 Duplicate` | An open issue already covers it | Mark `duplicateOf`, cite the key |
| `🗑️ Drop` | Refuted, speculative, no trigger, or covered elsewhere | Cancel with a signed comment naming the filter |
| `❓ Ask` | The verdict depends on intent only the user has | Ask the one question, then re-verdict |

## Step 4 — Table, then stop

```
Triage: <n> issues. Checked: <one line of what ran, e.g. "versions on apollon, allowlist on origin/main, blocker states">

1. 🔧 HOM-722: allow mealprep in auto-ok-pr.sh · P4 · E1
   → One word on one line; cheaper to fix than to queue.

2. 📋 Backlog HOM-723: skip CNF tests when data is absent · P4 · E1
   → Real. Backfill: add auto:ok, blockedBy HOM-722 (runner cannot open its PR yet).

3. 🗑️ HOM-726: re-run the AdGuard signal check on the next wave
   → Speculative: waits on an undated event; with auto:ok it would burn a nightly slot.

── Not kept ──
- HOM-726: speculative (trigger is a future event with no date)

Default on "go": the action column of each verdict above.
```

Rules: one line of reason per issue, the ticket key always beside words that say what it is, backfills named inline, the `Not kept` section always printed (say `none` when empty). Then **STOP** and wait: `go`, `go sauf <key>`, or a pick.

## Step 5 — Act on go

1. **Tracker moves first**, in parallel: state, backfilled metadata, relations. Linear `labels` replaces the whole set, so use `addLabels`. A label group allows one label (`claude:local` vs `claude:ariane`): swapping means removing the other in the same save.
2. **Drops:** post the comment first, then cancel. The comment names the filter and what would bring the issue back, and ends with:

   ```markdown

   ---

   *🤖 Drafted with `/triage`*
   ```
3. **Fix now**, one at a time, through `start-issue`. Check the PR's live state before reporting it.
4. **A fix now that gets refused** (a permission prompt denied, a host the session may not write to): do not route around it. Leave the issue in Todo with its labels intact and hand the user the exact command in its own code block.

## Step 6 — Report

Close with `adhd-summary`: task mode if a fix-now opened a PR, generic mode otherwise.

## Rules

- **Never act before approval.** The table is the deliverable of the first turn.
- **No verdict without a check.** "Looks still relevant" is not a check; a command output is.
- **Backfill on touch.** Every issue leaving triage carries full metadata, even the ones that are kept untouched otherwise.
- **Don't create issues here.** A new follow-up found while checking goes to `issues-candidate`.
