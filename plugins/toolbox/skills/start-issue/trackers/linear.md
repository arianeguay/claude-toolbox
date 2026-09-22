# Tracker: Linear (MCP)

Requires the Linear MCP server. Tools unavailable → stop; there is no CLI fallback for Linear.

URL shape: `https://linear.app/<workspace>/issue/<KEY>/<slug>` → the key is `<KEY>`.

## Read (Step 1)

```
get_issue      id: <KEY>  includeRelations: true
list_comments  issueId: <KEY>
```

`get_issue` returns the **git branch name** — that is the Step 2 branch, verbatim. It also
returns state, labels, estimate, priority, project, cycle and relations; check each against
the issue standard before building.

Blocked check: any `blockedBy` relation whose status type is not `completed`/`canceled`
blocks the start.

## Backfill (Step 1)

```
save_issue
  id:          <KEY>
  title:       <imperative, scoped, no key prefix>
  description: <markdown — literal newlines, no escape sequences>
  labels:      ["bug", "repo:<name>", ...]   # replaces the WHOLE set — pass every label the issue keeps
  estimate:    <number>
  priority:    1=Urgent 2=High 3=Medium 4=Low   # never 0
  project:     <name>          # when one applies
  cycle:       <number|name>   # when the team runs cycles
  blockedBy:   ["ABC-123"]     # ordering lives here, never in prose
```

Use `patch` instead of `description` for a surgical edit to a long body.

## State transitions (Steps 3 and 7)

State names are per-team — discover, never hardcode:

```
list_issue_statuses  team: <team>
```

Match by status **type**, then use the returned name:
- Step 3 → the `started` type (usually "In Progress")
- Step 7 → the `started`-type status named for review, else the review-ish `unstarted`
  status the team uses ("In Review"). No such status exists → say so and leave the issue in
  its Step 3 state.

```
save_issue  id: <KEY>  state: "<name from list_issue_statuses>"  assignee: "me"
```

Pass `assignee` only if the issue is unassigned. **Never combine this call with `links`**
(see below) — on claude-toolbox#19 the combination returned a `Duplicate attachment for
duplicate url` warning and left the state unapplied, with no error raised (STU-1474).
Re-read (`get_issue`) after saving and stop the flow if the state did not change.

**Step 7 sets the state after the link, not before.** The integration applies the team's
"PR opened" automation when it processes the PR event, which lands after the PR exists and
overwrites any state set ahead of it. On arr#45 an In Review saved with `attachments: []`
read back In Progress one call later, as the integration's attachment appeared (STU-1648).
Run the link step below first: poll `get_issue` for up to ~30 s until the PR URL shows in
`attachments`, fall back to the manual `links` save only then, and set the review state
last.

## Link the PR back (Step 7)

Read first, write only if missing — Linear's own GitHub/GitLab integration usually attaches
the PR/MR URL within seconds of the PR opening:

```
get_issue  id: <KEY>
```

Check the returned `attachments` for that URL. Only if absent:

```
save_issue  id: <KEY>  links: [{url: <pr url>, title: "<PR/MR #<n>>"}]
```

`create_attachment` is a deprecated base64 **file upload** (`base64Content`, `filename`,
`contentType`, `sha256` required) — it rejects a URL link outright and is not a substitute.

The attachment is belt-and-braces. The link Linear acts on comes from the PR/MR itself, and
its type decides what a merge does to the issue. Write one line in the description:

| Type | Line | On merge |
| -- | -- | -- |
| Resolves | `Fixes <KEY>` (also `closes`, `resolves`, `completes`, `implements`) | the team's "On merge" status, usually Done |
| Contributes | `Contributes to <KEY>` (also `ref`, `part of`, `towards`) | nothing; open and review events still move the issue |
| Related | `Related to <KEY>` (also `relates to`) | nothing, ever |

Measured, not assumed:

- A bare `<KEY>` in the description creates no link at all (2026-09-15, ops#55).
- The body line wins over the branch name. A PR on the `gitBranchName` branch with
  `Contributes to <KEY>` in its body merged and left the issue open, while the same team's
  merge automation closed Resolves-linked issues the day before (claude-toolbox#18,
  STU-1473). Keep using `gitBranchName` for every type.
- A key in the PR title combined with a contributing body line is untested, hence the
  title rule in Step 6.
- An issue linked to several PRs closes only when the last one merges.
- GitLab MRs never link from commit messages; GitHub commits can.
- Linear's GitLab page still files `related to` under contributing. Both skip the merge
  status, so the Related line is safe on either host.
- The link type is not readable back: `get_attachment` returns title and URL only. Do not
  report a type as verified; report the line written.
