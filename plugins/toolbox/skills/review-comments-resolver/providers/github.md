# Provider mechanics — GitHub (`gh`)

On GitHub, **resolution state lives only in GraphQL review threads** — the REST review-comment id is *not* the thread id. List with REST for convenience, but use GraphQL to know what's unresolved and to resolve.

```bash
OWNER_REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
OWNER=${OWNER_REPO%/*}; REPO=${OWNER_REPO#*/}
PR=$(gh pr view "$(git branch --show-current)" --json number -q .number)
```

## Detect the PR
```bash
gh pr view "$(git branch --show-current)" --json number,title,url,isDraft
```

## List comments
```bash
# Inline review comments (REST) — file/line/body/author/in_reply_to_id
gh api "repos/$OWNER/$REPO/pulls/$PR/comments" --paginate
# General PR comments (issue comments) — body/author, no position
gh api "repos/$OWNER/$REPO/issues/$PR/comments" --paginate
```

## Unresolved threads + mapping (GraphQL — source of truth)
```bash
gh api graphql -F owner="$OWNER" -F repo="$REPO" -F pr="$PR" -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
    reviewThreads(first:100){ nodes{
      id isResolved isOutdated
      comments(first:50){ nodes{ databaseId author{login} path line body } }
    }}}}}'
```
Each `node.id` is the **thread id** (for reply + resolve). Take threads where `isResolved == false`. Map a REST comment to its thread via the shared `databaseId` in the thread's `comments`.

## Identify bots (by `author.login`)
- **CodeRabbit** — `coderabbitai` / `coderabbitai[bot]`. Done when its summary comment exists (body contains `summarize by coderabbit.ai`).
- **Cursor Bugbot** — `cursor[bot]`. In-progress = it posted a "reviewing" comment / pending check and no finished summary yet; done = its review comment/summary is posted (or its check run concluded). Poll the issue/review comments every 30s (max ~10).

## Reply to a thread (keep open)
```bash
gh api graphql -F t="$THREAD_ID" -F body="$BODY" -f query='
mutation($t:ID!,$body:String!){ addPullRequestReviewThreadReply(
  input:{pullRequestReviewThreadId:$t, body:$body}){ comment{ id } } }'
```
For a **general** (non-thread) comment, reply with another issue comment: `gh pr comment "$PR" --body "$BODY"`.

## Resolve a thread
```bash
gh api graphql -F t="$THREAD_ID" -f query='
mutation($t:ID!){ resolveReviewThread(input:{threadId:$t}){ thread{ isResolved } } }'
```
(Never resolve a `❓ Clarify` thread — leave it open for the reviewer.)

## Auth / errors
- Not authenticated → `gh auth login`.
- GraphQL needs the repo's `read`/`write` scopes; resolving requires write access to the PR.
