# PROFILE.example.md

Per-project settings the toolbox skills read. Copy to `PROFILE.md` in the repo you're
working in (or to `~/.claude/PROFILE.md` for machine-wide defaults) and fill it in.

**Keep the filled-in copy out of version control.** Use `.git/info/exclude` in the
consuming repo, not `.gitignore` — `.gitignore` is itself committed, so adding `PROFILE.md`
to it publishes the fact that the file exists and invites someone to commit theirs. Add the
line to `.git/info/exclude` instead, which is local to your clone and never pushed:

```bash
echo 'PROFILE.md' >> "$(git rev-parse --git-dir)/info/exclude"
```

This matters on a shared or public repo: the file names internal hosts, ticket prefixes and
branch conventions. It is per-developer config, not project config — a teammate who wants
the same behaviour writes their own, or the values stay in whatever tooling the team
already shares.

Every field is optional. A skill that can't find its field falls back to detection, or
skips the step and says so — it never guesses.

---

## Tracker

```
TICKET_PREFIX=ABC          # ticket key prefix, e.g. ABC-1234 — used to parse branch names
TRACKER=github             # github | gitlab | linear | jira | none
```

Read by: `plan` (extract the ticket id from the branch), `mechanical-checks` (accept
`ABC-1234` as a valid TODO reference), `issues-candidate` (where to file follow-ups),
`create-or-update-mr` (narrow the branch-name match to this repo's tracker, so a branch
whose title happens to contain another `XX-123` can't yield the wrong key).

## Branches

```
PRODUCTION_BRANCH=         # e.g. master — what hotfix/* targets
```

Read by: `create-or-update-mr`. The *default* target needs no key: it comes from
`origin/HEAD`, which already resolves to a non-`main` trunk (e.g. `origin/develop`)
without configuration. Set this only when `hotfix/*` should target something other than
`master`, or `master` doesn't exist on the remote.

## Shaping

```
SHAPING_DIR=               # absolute path to persisted shaping bundles, e.g. ~/notes/shaping
```

Read by: `plan` and `context-validator`, to find `${SHAPING_DIR}/<TICKET>.md` and use its
scope sections as the intent source. Leave empty if you don't use shaping bundles — both
skills fall back to the PR/MR description, then the branch name.

## Checks

```
LINT_CMD=                  # e.g. npm run lint:fix
TYPECHECK_CMD=             # e.g. npm run type-check
TEST_CMD=                  # e.g. npm test
```

Read by: `mr-ship` step 3. Left empty, it detects from `package.json` scripts, `Makefile`,
`pyproject.toml`, or `composer.json`; if nothing is found the step is skipped, never
invented.

## Project docs

```
PROJECT_DOCS=              # space-separated paths to convention/edge-case docs, e.g. docs/TEST_GUIDELINES.md docs/EDGE_CASES.md
```

Read by: `context-validator` — scans the diff against each listed doc that exists; skips
any path that doesn't, and skips the whole step if left empty.

## App under test

```
APP_URL=http://localhost:3000
```

Read by: `browser-test`.

**Credentials do not go in this file.** If the dev server needs a login, put it in your
password manager or a gitignored `.env` and let the skill ask — never commit credentials
to a repo, including a private one.

## Status checks

```
STATUS_SERVICES=gitlab github anthropic    # default set for /is-it-down with no argument
```

Read by: `is-it-down`.
