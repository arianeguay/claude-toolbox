# PROFILE.example.md

Per-project settings the toolbox skills read. Copy to `PROFILE.md` in the repo you're
working in (or to `~/.claude/PROFILE.md` for machine-wide defaults) and fill it in.

`PROFILE.md` is gitignored by this repo — keep the filled-in copy out of version control
if it names internal hosts, ticket prefixes, or anything else you don't want published.

Every field is optional. A skill that can't find its field falls back to detection, or
skips the step and says so — it never guesses.

---

## Tracker

```
TICKET_PREFIX=ABC          # ticket key prefix, e.g. ABC-1234 — used to parse branch names
TRACKER=github             # github | gitlab | linear | jira | none
```

Read by: `plan` (extract the ticket id from the branch), `mechanical-checks` (accept
`ABC-1234` as a valid TODO reference), `issues-candidate` (where to file follow-ups).

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
