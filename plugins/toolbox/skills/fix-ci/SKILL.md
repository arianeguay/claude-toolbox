---
name: fix-ci
description: Detect and fix CI pipeline failures — reads job logs, parses errors (lint, type-check, tests, build), applies fixes, and re-pushes. Use when asked to "fix CI", "fix pipeline", "fix the build", "why is CI failing", or when a pipeline fails after a push.
user-invocable: true
---

# Fix CI Skill

I'm using the fix-ci skill to diagnose and fix CI pipeline failures.

**Core principle:** Read the actual error logs, fix only what's broken, verify locally with the same checks CI runs, push.

---

## Step 0: Detect the host CLI and the project's checks

**Host CLI** — pick from the remote so the rest of the steps use the right tool:

```bash
REMOTE=$(git remote get-url origin 2>/dev/null)
case "$REMOTE" in
  *gitlab*) CLI=glab ;;   # GitLab CLI
  *github*) CLI=gh   ;;   # GitHub CLI
  *)        CLI=      ;;   # unknown → ask the user which CI host they use
esac
```

**Local checks** — discover what CI runs so Step 6 can mirror it. Don't hardcode; detect:

| Ecosystem | Where checks live | Typical lint / type / test / build |
|-----------|-------------------|-------------------------------------|
| JS/TS | `package.json` `scripts` | `npm run check` / `npm run type-check` / `npm test` / `npm run build` |
| Python | `pyproject.toml`, `tox.ini`, `Makefile` | `ruff`/`flake8` / `mypy` / `pytest` / — |
| Rust | `Cargo.toml` | `cargo clippy` / `cargo check` / `cargo test` / `cargo build` |
| Go | `go.mod`, `Makefile` | `go vet` / — / `go test ./...` / `go build ./...` |

Prefer the project's own script names (`cat package.json | jq .scripts`, `grep -E '^[a-z].*:' Makefile`) over assumed commands — the CI config (`.gitlab-ci.yml` / `.github/workflows/*.yml`) is the source of truth for what actually runs.

---

## Step 1: Find the Failing Pipeline

**GitLab (`glab`):**
```bash
glab ci view --branch "$(git branch --show-current)" -F json 2>/dev/null \
  || glab ci list --branch "$(git branch --show-current)" -F json
```

**GitHub (`gh`):**
```bash
gh run list --branch "$(git branch --show-current)" --limit 1 \
  --json databaseId,status,conclusion,workflowName,url
```

Take the most recent run. Extract its id, status/conclusion, and URL.

- If it's still running, poll every 30s (max 10 cycles) until it completes.
- If it passed, report and stop: `Pipeline on branch '{branch}' passed. Nothing to fix.`

---

## Step 2: Identify Failed Jobs

**GitLab:**
```bash
glab api "projects/:id/pipelines/{pipeline_id}/jobs"   # filter status == "failed"
```

**GitHub:**
```bash
gh run view {run_id} --json jobs \
  --jq '.jobs[] | select(.conclusion=="failure") | {name, databaseId}'
```

Report what failed (job name + stage/workflow).

---

## Step 3: Read Job Logs

**GitLab:**
```bash
glab ci trace {job_id}   # or: glab api projects/:id/jobs/{job_id}/trace
```

**GitHub:**
```bash
gh run view {run_id} --log-failed   # only failed steps
# or a single job: gh run view --job {job_id} --log
```

**Parse the logs** to extract actionable errors — file path, line, rule/code, message. Common formats:

```
# Biome (JS/TS lint/format)   src/path/file.ts  format|lint/rule  ━━━
# tsc (TypeScript)            src/path/file.ts(line,col): error TSxxxx: message
# Vitest/Jest (JS tests)      FAIL src/x.test.ts > describe > test   → AssertionError
# Vite/Rollup (build)         error during build: ... failed to resolve import
# ruff/flake8 (Python lint)   path/file.py:line:col: CODE message
# mypy (Python types)         path/file.py:line: error: message  [code]
# pytest (Python tests)       FAILED path/test_x.py::test_name - AssertionError
# cargo (Rust)                error[Exxxx]: message  --> src/file.rs:line:col
# go                          path/file.go:line:col: message
```

Pick the parser(s) matching the failed job's ecosystem.

---

## Step 4: Present Diagnosis

Show each error with the proposed fix, then ask the user:

```
Pipeline — {N} error(s) in '{job_name}':

1. src/components/Foo.tsx:42 — TS2322: Type 'string' not assignable to 'number'
   → Fix the type mismatch
2. src/utils/bar.ts — lint/format violation
   → Run the autofix
```

- **"Fix all"** — fix everything and push
- **"Let me pick"** — user selects which to fix
- **"Show logs"** — dump raw logs for manual inspection

---

## Step 5: Apply Fixes

- **Lint/format** — run the project's autofix first (`npm run check:fix`, `ruff --fix`, `cargo clippy --fix`, `gofmt -w`). It clears most mechanical issues.
- **Type errors** — read the file at the error location, understand the mismatch, fix it.
- **Test failures** — read the test and the source it covers. Decide: outdated test (update test), real bug (fix source), or changed expectation (update assertion).
- **Build errors** — usually missing imports, circular deps, or deleted files still referenced. Fix the import chain.

---

## Step 6: Verify Locally

Run the **same checks CI runs** (from Step 0):

```bash
# Example (JS/TS); substitute the project's detected commands
npm run check && npm run type-check && npm test
```

If any check still fails, return to Step 5 for that specific error. **Do not push if local verification fails.**

---

## Step 7: Commit and Push

Stage only the fixed files (not unrelated changes), then commit with your usual commit convention/skill:

```
fix(ci): resolve lint/type-check/test failures

- Fix format violations in Foo.tsx
- Fix TS2322 type mismatch in Bar.tsx:42
- Update test assertion in useBaz.test.ts
```

```bash
git push   # triggers a new pipeline
```

Report the new pipeline URL.

---

## Step 8: Monitor (Optional)

If the user wants, poll the new run (`glab ci view` / `gh run watch {run_id}`) every 30s, max 20 cycles (10 min). Report when it passes or fails again.

---

## Error Handling

| Condition | Action |
|-----------|--------|
| Unknown host (no glab/github remote) | Ask which CI host the project uses before proceeding. |
| No pipeline found | "No pipeline found for branch '{branch}'. Push first or check the branch name." |
| Pipeline still running | Poll every 30s, max 10 cycles. If still running: "Still running after 5 min. Check manually: {url}" |
| CLI not authenticated | "CI CLI not authenticated. Run `glab auth login` / `gh auth login`." |
| Job logs too long (>10k lines) | Read only the last 500 lines — errors are at the end. |
| Fix introduces new errors | Report to user, don't push. "Fix for X introduced error Y — needs manual review." |
| All jobs passed but pipeline failed | Likely infrastructure (runner, timeout). Report as non-fixable. |
