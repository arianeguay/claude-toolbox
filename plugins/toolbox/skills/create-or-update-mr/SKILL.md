---
name: create-or-update-mr
model: haiku
description: Draft or update a PR/MR title and description from the branch diff, then push and open it after validation. Triggers - "create an MR/PR", "open a merge request", "describe MR/PR", "write a PR description", "prepare the merge request", "update the MR", or before pushing a branch for review.
---

# PR/MR Description

Generate or update a professional PR/MR title + description from the branch diff, then push after user validation. Provider-agnostic (GitHub `gh` / GitLab `glab`).

## Process
1. Gather context (branch, base, ticket, diff)
2. **Check for an existing PR/MR** — fetch its current title + description
3. Analyze the diff (intent, decisions, risks, UI?)
3.5. **If UI changed:** capture real screenshots via Chrome DevTools MCP, upload, embed
4. Generate or update title + description, **preserving existing content**
5. Present to the user for approval
6. Push (create or update)

---

## Step 1 — Context

```bash
BRANCH=$(git branch --show-current)
ROOT=$(git rev-parse --show-toplevel)
# PROFILE.md supplies per-project values; repo root wins over the machine-wide copy.
# Every key is optional — an unset key falls back to detection, never to a guess.
prof() { sed -n "s/^$1=//p" "$ROOT/PROFILE.md" ~/.claude/PROFILE.md 2>/dev/null | grep . | head -1; }

# Base = the remote's default branch. This already resolves correctly on repos
# whose trunk isn't `main` (origin/HEAD -> origin/develop), so no key is needed
# for the common case.
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@origin/@@' || echo main)
# hotfix/* targets the production branch: PRODUCTION_BRANCH if set, else master
# if it exists on the remote, else the default.
PROD=$(prof PRODUCTION_BRANCH)
case "$BRANCH" in
  hotfix/*) TARGET=${PROD:-$(git show-ref --verify -q refs/remotes/origin/master && echo master || echo "$DEFAULT")} ;;
  *)        TARGET="$DEFAULT" ;;
esac
git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "NOT_PUSHED"
BASE=$(git merge-base HEAD "origin/$TARGET")
# TICKET_PREFIX narrows the match to the repo's own tracker, so a branch like
# feature/gra-3233-... can't yield a key from some other prefix in the name.
PREFIX=$(prof TICKET_PREFIX)
TICKET=$(echo "$BRANCH" | grep -oiE "${PREFIX:-[A-Z]+}-[0-9]+" | head -1 | tr '[:lower:]' '[:upper:]')
# Overview first. Exclude lockfiles/snapshots/generated files so the diff stays readable.
git diff --stat "$BASE"..HEAD -- . ':(exclude)*lock*' ':(exclude)*.snap'
git log --oneline "$BASE"..HEAD
git diff "$BASE"..HEAD -- . ':(exclude)*lock*' ':(exclude)*.snap'
```
If not pushed, push first (`git push -u origin "$BRANCH"`) — **ask before pushing** if the user hasn't said to. If no ticket id in the branch name and the repo uses one, ask.

**On a large branch, do not dump the whole diff.** A multi-thousand-line diff can trigger a context compaction mid-skill, and the description then gets written from a summary of the diff rather than the diff — which is how a "Decisions" section ends up describing work that isn't there. Read the `--stat` and the commit log, pick the files that carry the change, and pull targeted diffs of those (`git diff "$BASE"..HEAD -- <path>`). Reach for the full diff only when the branch is genuinely small.

---

## Step 2 — Check for an existing PR/MR (NEVER SKIP)

Skipping loses screenshots, user edits, and bot comments on update.

```bash
gh pr view "$BRANCH" --json number,title,body,url,isDraft 2>/dev/null \
  || glab mr view "$BRANCH" -F json 2>/dev/null
```
If one exists, parse its body and identify content to **preserve**:
- Screenshots / images (`![...](...)`) that aren't the TODO placeholder — **never delete**
- User-added custom sections
- Bot sections (CodeRabbit, Bugbot/Cursor, etc.) — **never delete or regenerate**

Merge preserved content into `$DESCRIPTION` now, so by Step 6 it's complete.

---

## Step 3 — Analyze the diff
Area touched (→ scope) · primary intent (feat/fix/refactor/…) · non-obvious decisions · risk zones (shared code, data mutations) · UI change? (→ screenshot).

---

## Step 3.5 — Capture real screenshots (when the diff touches UI)

If the diff changes `*.tsx`/`*.jsx`/templates (a UI change), try to capture real screenshots instead of a placeholder — always prefer a real screenshot over `📸 TODO`.

**Preconditions:**
- Chrome DevTools MCP tools are available (`ToolSearch` for `mcp__chrome-devtools__*`, or already loaded). If the server won't start, check its `command` resolves — a bare `npx` fails when the MCP env's `PATH` lacks the Node install; use an absolute path.
- The repo has a known local-dev login (check memory for a reference like "local dev login" — username/password to authenticate the app before navigating).
- A dev server **serving the branch under review** — resolve it per Step 3.5.0, don't assume one is up.

If a precondition can't be met, fall back per the rule at the end of this step — and **name the failed precondition in the final report**, never fall back silently.

### Step 3.5.0 — Resolve a dev server for *this* worktree

A reachable `localhost:3000` proves nothing: it's often another worktree's server, so the screenshots would show the wrong branch.

1. **Identify the listener** on the expected port:
   ```bash
   PID=$(lsof -nP -iTCP:3000 -sTCP:LISTEN -t | head -1)
   [ -n "$PID" ] && lsof -a -p "$PID" -d cwd -Fn | sed -n 's/^n//p'   # its working dir
   ```
2. **Compare** that dir to `git rev-parse --show-toplevel`. Same → reuse it. Different → it belongs to another worktree or session.
3. **Never kill a server you didn't start** — a concurrent session is probably using it. Start your own on a free port instead (`3100`, `3200`, …), reading the dev script from `package.json` (`start`/`dev`):
   ```bash
   pnpm start -- --port 3100 --strictPort > /tmp/mr-devserver.log 2>&1 &
   ```
   Run it detached from the repo root, then poll until `curl -s -o /dev/null -w '%{http_code}' http://localhost:3100` returns `200` (give it up to ~60s; on timeout, read the log and fall back).
4. **Use the resolved port** for every navigation in the procedure below.
5. **Stop only a server this step started**, after the uploads are done. Leave a pre-existing one running.

**Procedure:**
1. **Log in** (if the app is behind auth): `new_page` to the app's login route, `fill` credentials, `click` submit, `take_snapshot` to confirm landing.
2. **Navigate** to each route the diff actually affects (derive from the ticket/component names — e.g. a Forecast component change → the Forecast tab route).
3. **Screenshot** each affected state with `take_screenshot(fullPage: true, filePath: ...)`. Chrome DevTools MCP enforces its own workspace-root restriction — save under a path inside the repo working tree (e.g. `.mr-screenshots/<name>.png`), **not** `/tmp` or an external scratchpad, or the write will be rejected.
4. **Capture one screenshot per distinct scenario the ticket/diff describes** (e.g. each of N described bugs/states), not just one generic "it works" shot.
5. **Upload each PNG to the host so it can be embedded in the description:**
   - **GitLab:** upload via the project's uploads endpoint, then use the returned `markdown` field's URL directly in the description:
     ```bash
     TOKEN=$(glab config get token --host gitlab.com)   # --host, not -h
     curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
       --form "file=@.mr-screenshots/<name>.png" \
       "https://gitlab.com/api/v4/projects/<url-encoded-namespace%2Frepo>/uploads"
     # → {"markdown":"![name](/uploads/<hash>/name.png)", ...} — use the url/markdown field
     ```
     (`glab api --field file=@path` does NOT do a multipart upload — it JSON-encodes the value. Use `curl` with `--form` directly.)
     **`401 Unauthorized` on a token that works for every other call → retry with `Authorization: Bearer $TOKEN`.** Some projects reject `PRIVATE-TOKEN` on the uploads endpoint specifically; the same token succeeds as a Bearer. Try `PRIVATE-TOKEN` first, fall back to Bearer, and only then treat it as a real auth failure.
   - **GitHub:** no simple REST equivalent for arbitrary image upload into a PR body — don't attempt it. Fall back to `📸 TODO: add before merging` and note in the report that screenshots need manual attachment.
6. **Embed** the returned image URLs in the Screenshots section (see Step 4's narrative-walkthrough rule for ≥3 images — one short paragraph of *why this scenario is shown* before each image, referencing the specific behavior it demonstrates).
7. **Clean up:** delete the local `.mr-screenshots/` directory once uploaded (images now live on the host, not the repo). Before deleting, run `git status --porcelain` — if the files were staged by anything else, `git restore --staged` them first so the delete doesn't get bundled into an unrelated commit. Never commit screenshot files to the branch.

**If any precondition fails** (dev server couldn't be started, tool unavailable, no known login, diff is a pure refactor/backend/no visual surface): use the existing `📸 TODO: add before merging` or `N/A — no UI change` fallback — don't block the rest of the pipeline on this. **State which precondition failed and why in the final report** (e.g. "no screenshots: `mcp__chrome-devtools__*` unavailable"), so a silent `📸 TODO` is never mistaken for "the diff has no UI".

**Multi-step flow → prefer video over a screenshot stack.** A static image can't show a before/after transition, an animation, or a multi-click sequence. If `playwright-cli` is installed (see `toolbox:browser-test` for the tool-selection table — it's the only one of the three that records) and the diff is that kind of flow, record instead:
```bash
playwright-cli -s=<repo> video-start .mr-screenshots/demo.webm
# drive the flow: goto / click / fill / etc.
playwright-cli -s=<repo> video-chapter "Step label"   # optional markers per step
playwright-cli -s=<repo> video-stop
```
Upload the same way as a screenshot (Step 3.5.5 above) — the GitLab uploads endpoint and the `curl --form` requirement are identical for any file type, not just PNG. Delete the local file after upload, same cleanup rule as screenshots. Single-state UI changes still get a plain screenshot — video is the upgrade for flows, not the new default.

---

## Step 4 — Generate or update

**Title:** `<type>(<scope>): <Description>` — Conventional-Commits type, scope = area, imperative, capitalized. Ticket id goes in the body, not the title.

**Description** (keep it tight — the reviewer reads diffs):
```markdown
## Why
[1–2 sentences. Problem solved. Link the ticket.]
## What
[Approach summary; the "how" only when non-obvious.]
## Decisions
[Optional — only real trade-offs, one line each.]
## Risks / Attention
[Optional — shared code, edge cases, temporary workarounds.]
## Screenshots
[Always present.]

<sub>🤖 Drafted with <code>/create-or-update-mr</code></sub>
```

**The footer is part of the template, not optional.** The MR is authored by whoever owns the host token — the person who approved the description in Step 5 — and that authorship is right, because the *decision* to open it is theirs. The footer supplies the half a reviewer needs: that the prose was machine-drafted, so a confident-sounding "Decisions" section is read as a claim to check rather than a considered account. Fixed string, never reworded per MR. On an **update**, if the existing description already carries it, don't add a second one.

**Updating an existing description:** keep screenshots/user sections/bot sections; replace a `📸 TODO` only if you have real screenshots; regenerate stale Why/What from the diff (the diff is source of truth); show a diff-style preview of what changed vs preserved.

**Include:** the change↔problem link, real architecture decisions, risk flags, out-of-scope notes. **Skip:** per-file lists, obvious patterns, restating the ticket, boilerplate that doesn't apply.

**Screenshots:** prefer real images captured per Step 3.5; fall back to `📸 TODO: add before merging` only if a precondition there fails; for a pure refactor write `N/A — no UI change`. **When ≥3 screenshots, write a narrative walkthrough** grouped by scenario (a short paragraph explaining *why each scenario is shown* before each image), not an alt-text gallery.

---

## Step 5 — Present for validation
Always show the full title + description and wait for explicit approval (`yes` / `edit first`). For an existing PR/MR, show the old title alongside and what was preserved vs regenerated.

---

## Step 6 — Push

**Draft state:** new PRs/MRs default to **Draft**. Existing ones keep their current state unless the user says otherwise — if flipping Draft↔Ready, ask first.

**GitHub (`gh`):**
```bash
# create (draft by default)
gh pr create --base "$TARGET" --head "$BRANCH" --title "$TITLE" --body "$DESCRIPTION" --draft
# update
gh pr edit "$BRANCH" --title "$TITLE" --body "$DESCRIPTION"
gh pr ready "$BRANCH"   # or: gh pr ready --undo   (to set Draft)
```

**GitLab (`glab`):**
```bash
# create — Draft via the "Draft: " title prefix
glab mr create --source-branch "$BRANCH" --target-branch "$TARGET" --title "Draft: $TITLE" --description "$DESCRIPTION" --no-editor
# update — pass --draft OR --ready EXPLICITLY (omitting both flips a Draft MR to Ready when the title has no "Draft: " prefix); strip any "Draft: " prefix from $TITLE first
glab mr update "$MR_IID" --title "$TITLE" --description "$DESCRIPTION" --draft   # or --ready
```

After pushing: show the URL; if the screenshots section still has the TODO placeholder, say **which Step 3.5 precondition failed** and remind to add them before requesting review.

---

## Error handling
| Condition | Action |
|-----------|--------|
| CLI not authenticated | STOP — `gh auth login` / `glab auth login` |
| No commits ahead of base | STOP — nothing to describe |
| No ticket id and repo uses one | WARN — generate without it, note in output |
| create fails | Show error — usually branch not pushed, or a PR/MR already exists (→ update flow) |
