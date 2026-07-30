# Tracker: Linear (MCP)

Requires the Linear MCP server. If its tools aren't available, fall back to `github.md` / `gitlab.md`, else Step 7.

## Discover the destination

```
list_teams                       # team is required on create
list_issue_labels  team: <team>  # label names must already exist
list_projects      team: <team>
list_cycles        team: <team>  # current cycle, if the team runs cycles
```

Pick the team from the repo's own convention (`CLAUDE.md`/`AGENTS.md` usually names the issue key prefix, e.g. `STU-` → that team). Ambiguous → ASK, don't guess.

## Dedup search (Step 3)

```
list_issues  team: <team>  query: "<3-5 distinctive words from the title>"  limit: 20
             fields: ["title","status","statusType","url"]
```
Run one search per candidate. A hit in any non-`completed`/`canceled` state → drop the candidate and cite the existing key. Search title words, not your phrasing of the fix.

## Create (Step 6A)

```
save_issue
  team:        <team>
  title:       <imperative title>
  description: <markdown body — literal newlines, no escape sequences>
  labels:      ["bug", ...]        # replaces the full set; omit if none
  priority:    1=Urgent 2=High 3=Medium 4=Low   # never 0
  estimate:    <number>            # never omit
  project:     <name>              # when one applies
  cycle:       <number|name>       # when the team runs cycles and it belongs in one
  blockedBy:   ["ABC-123"]         # ordering goes here, never in the body
```

Notes:
- `labels` **replaces** the whole label set — always pass every label the issue needs, not just the new one.
- `blockedBy`/`blocks`/`relatedTo` are append-only. `blockedBy` is the ordering primitive; don't express "do X first" in prose.
- Do **not** pass `id` when creating.
- `assignee: "me"` if the user is picking the work up themselves.

## Body template

```markdown
**Symptom** — <what is observably wrong / missing>

**Where** — `path/to/file.py:212` (or: surfaced while doing <task>)

**Why not in <current task>** — <one line>

**What a fix involves** — <2-4 lines: the approach, and what proves it>
```

Return the created issue's identifier + URL for the Step 8 report.
