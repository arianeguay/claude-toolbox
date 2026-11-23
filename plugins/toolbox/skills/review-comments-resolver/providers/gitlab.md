# Provider mechanics — GitLab (`glab`)

GitLab keeps comments as **notes** grouped into **discussions**; resolution is a field on the discussion.

```bash
MR="${MR_NUMBER:-$(git branch --show-current)}"   # MR_NUMBER = the skill argument, if given
IID=$(glab mr view "$MR" -F json | jq -r .iid)
# `:id` in the paths below is glab's placeholder for the current project — leave it literal.
```

## Detect the MR
```bash
glab mr view "$MR" -F json   # iid, title, web_url
```

## List comments
```bash
# Threads (ids to reply to and resolve): explicit page loop, never --paginate,
# which silently dropped discussions on a large MR.
page=1; while :; do
  out=$(glab api "projects/:id/merge_requests/$IID/discussions?per_page=100&page=$page")
  [ "$(echo "$out" | jq length)" -eq 0 ] && break
  echo "$out"; page=$((page+1))
done
# Completeness check only: /notes has no `discussion_id`, so it can't give thread ids.
glab api "projects/:id/merge_requests/$IID/notes" --paginate
```
Each discussion's `id` (hex) is what you reply to and resolve; its `notes[]` hold the thread. Unresolved = a discussion with a `resolvable: true` note whose `resolved` is false. Also collect discussions whose first note is `resolvable: false` with no `position`: GitLab never makes a plain overview comment resolvable, so the filter alone drops human general feedback. Inline = `position != null`; general = `position == null`. If the unresolved count from `/notes` exceeds the one from `/discussions`, a page was dropped: re-fetch before triaging.

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
(Never resolve a CodeRabbit thread either, and don't `@coderabbitai` inside it — see SKILL.md 8B. Once all its findings are handled, post one general comment:)
```bash
glab api "projects/:id/merge_requests/$IID/notes" --method POST -f body="@coderabbitai resolve"
```
Then, once CodeRabbit answers, resolve the discussion that now holds that note (find it by the note id in `…/discussions`, then use the resolve call above). It's your discussion, not a finding.

## Auth / errors
- Not authenticated → `glab auth login`.
- If unresolved count looks low vs the MR UI, compare with the `/notes` count (see List comments).
