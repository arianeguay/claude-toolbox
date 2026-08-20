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

Pass `assignee` only if the issue is unassigned.

## Link the PR back (Step 7)

```
create_attachment  issueId: <KEY>  url: <pr url>  title: "<PR/MR #<n>>"
```

Linear also auto-links when the branch name came from `get_issue` and the PR body carries
the key — the attachment is the belt-and-braces, not the mechanism.
