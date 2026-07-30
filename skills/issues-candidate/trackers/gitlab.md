# Tracker: GitLab Issues (`glab`)

GitLab has native `weight` (estimate) and scoped labels (`priority::high`). Use those rather than inventing a convention.

```bash
glab auth status || echo "STOP — glab auth login"
glab api "projects/:id/labels?per_page=100" | jq -r '.[].name'
glab api "projects/:id/milestones?state=active" | jq -r '.[] | "\(.id) \(.title)"'
```

## Dedup search (Step 3)

```bash
glab issue list --all --search "<3-5 distinctive title words>" -F json \
  | jq -r '.[] | "\(.iid) \(.state) \(.title)"'
```
A hit that isn't `closed` → drop the candidate, cite `#<iid>`. One search per candidate.

## Create (Step 6A)

```bash
glab issue create \
  --title "<imperative title>" \
  --label bug --label "priority::high" \
  --weight 2 \
  --milestone "<milestone>" \
  --description "$(cat <<'EOF'
**Symptom** — <what is observably wrong / missing>

**Where** — `path/to/file.py:212` (or: surfaced while doing <task>)

**Why not in this MR** — <one line>

**What a fix involves** — <2-4 lines: approach + what proves it>
EOF
)"
```

## Ordering (blockedBy)

Premium+ only; on a free tier it degrades to a related link:

```bash
# blocked-by link (premium): target_project_id + target_issue_iid + link_type
glab api -X POST "projects/:id/issues/<NEW_IID>/links" \
  -f target_project_id="<project_id>" -f target_issue_iid="<BLOCKER_IID>" -f link_type=is_blocked_by
```
If the API rejects `link_type` (tier limitation), create the link as `relates_to` **and** write `Blocked by #<iid>` in the description so the ordering is still recorded.

Report the returned issue URL for Step 8.
