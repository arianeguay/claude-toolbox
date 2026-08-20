# Tracker: GitLab Issues (`glab`)

```bash
glab auth status || echo "STOP — glab auth login"
```

URL shape: `https://gitlab.com/<group>/<project>/-/issues/<iid>` → the key is `#<iid>`.

GitLab has no workflow-state field either: an issue is `opened` or `closed`. Boards read
**scoped labels** (`workflow::in progress`) — that is the mechanism. Detect the project's
existing scope before using one:

```bash
glab api "projects/:id/labels?per_page=100" | jq -r '.[].name' | grep '::'
```

## Read (Step 1)

```bash
glab issue view <iid> --comments
glab api "projects/:id/issues/<iid>" | jq '{title,state,labels,weight,milestone,assignees,web_url}'
glab api "projects/:id/issues/<iid>/links" | jq -r '.[] | "\(.iid) \(.link_type) \(.state) \(.title)"'
```

Blocked check: a link with `link_type: is_blocked_by` whose state is `opened` blocks the
start. On a free tier the links degrade to `relates_to` — read the description for
`Blocked by #<iid>` as well.

## Backfill (Step 1)

```bash
glab issue update <iid> \
  --title "<imperative, scoped, no key prefix>" \
  --description "$(cat <<'BODY'
<markdown body>
BODY
)" \
  --label bug --unlabel wontfix
```

`--label` on `issue update` is additive; `--unlabel` removes. Estimate is the native
`weight`, priority a scoped label — set both through the API when the CLI flag is missing:

```bash
glab api -X PUT "projects/:id/issues/<iid>" -f weight=2 -f milestone_id=<id>
```

## Branch name (Step 2)

GitLab's own convention — and what its "create branch" button generates — is
`<iid>-<slugified-title>`. A branch starting with `<iid>-` auto-links to the issue and
makes the MR close it. Create it through the API so the link registers server-side:

```bash
DEFAULT=$(glab api "projects/:id" | jq -r .default_branch)
glab api -X POST "projects/:id/repository/branches" -f branch="<iid>-<kebab-title>" -f ref="$DEFAULT"
git fetch origin "<iid>-<kebab-title>"
git worktree add .claude/worktrees/<iid>-<kebab-title> "<iid>-<kebab-title>"
```

Keep the `<iid>-` prefix whatever else the title becomes — that prefix *is* the link.

## State transitions (Steps 3 and 7)

Scoped labels are mutually exclusive within their scope, so setting the new one drops the
old — no `--unlabel` needed:

```bash
glab issue update <iid> --label "workflow::in progress"    # Step 3
glab issue update <iid> --label "workflow::in review"      # Step 7
glab issue update <iid> --assignee "@me"                   # if unassigned
```

The project uses no scoped workflow labels → assignment is the only honest signal; say so
in the Step 8 report instead of inventing a label scope. Never close the issue as a
stand-in for "in review".

## Link the MR back (Step 7)

`Closes #<iid>` in the MR description is GitLab's native link and closes the issue on merge.
For an MR that shouldn't close it, use `Related to #<iid>` and comment the URL:

```bash
glab issue note <iid> --message "MR: <url>"
```

Draft MRs: prefix the title with `Draft:` — GitLab's own marker, not a label.
