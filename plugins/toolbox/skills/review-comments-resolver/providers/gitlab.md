# Provider mechanics — GitLab (`glab`)

GitLab keeps comments as **notes** grouped into **discussions**; resolution is a field on the discussion.

```bash
IID=$(glab mr view "$(git branch --show-current)" -F json | jq -r .iid)
# `:id` in the paths below is glab's placeholder for the current project — leave it literal.
```

## Detect the MR
```bash
glab mr view "$(git branch --show-current)" -F json   # iid, title, web_url
```

## List comments
```bash
# Use /notes (NOT /discussions) — /discussions --paginate silently drops items on large MRs.
glab api "projects/:id/merge_requests/$IID/notes" --paginate
```
Notes are flat; group by `discussion_id` to reconstruct threads. Unresolved = note with `resolvable: true` and `resolved: false`. Inline = `position != null`; general = `position == null`. The `discussion_id` (hex) is what you reply to and resolve.

## Identify bots (by `author.username`)
- **Cursor Bugbot** — `^project_\d+_bot_`.
- **CodeRabbit** — `^group_\d+_bot_` or `coderabbitai`. Done when its summary note (body contains `summarize by coderabbit.ai`) appears.

## Bot in-progress (award emoji)
```bash
glab api "projects/:id/merge_requests/$IID/award_emoji"                 # MR-level (auto mode)
glab api "projects/:id/merge_requests/$IID/notes/$NOTE_ID/award_emoji"  # on a `bugbot run` / `@cursor review` trigger note
```
`eyes` from a `^project_\d+_bot_` user = still running; `thumbsup`/`white_check_mark` with no `eyes` = done. Poll every 30s (max ~10).

## Reply to a discussion (keep open)
```bash
glab api "projects/:id/merge_requests/$IID/discussions/$DISCUSSION_ID/notes" \
  --method POST -f body="$BODY"
```

## Resolve a discussion
```bash
# PUT on the discussion itself (NOT a /resolve sub-path); -f (not --field).
glab api "projects/:id/merge_requests/$IID/discussions/$DISCUSSION_ID" \
  --method PUT -f resolved=true
```
(Never resolve a `❓ Clarify` discussion — leave it open for the reviewer.)

## Auth / errors
- Not authenticated → `glab auth login`.
- If unresolved count looks low vs the MR UI, cross-check with `…/discussions --paginate` as a secondary source and merge — but `/notes` is primary.
