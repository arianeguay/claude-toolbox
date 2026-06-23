# Context validation — PHP

When the diff touches `*.php`. **Extend per repo.** Framework questions fire only when relevant files are present.

## Automated (I read the changed code and report)
- **N+1 trace** — Eloquent/Doctrine queries inside loops or accessors without eager loading (`with()` / `fetchJoin`).
- **Public API / contract breaks** — changed route signatures, response payload shapes, or form-request rules existing clients depend on.
- **Unbound queries** — raw SQL with interpolated variables (injection risk) added in the diff.

## Targeted human questions (ask only the relevant sections)

**Endpoints / controllers changed:**
- Tested end-to-end with a real request, happy path?
- Backward compatible — renamed/removed response fields won't break consumers?
- Auth / policy — right user allowed, wrong user rejected?

**Migrations changed:**
- Forward migration runs cleanly locally?
- `down()` tested or documented as non-reversible?
- Safe on a populated prod DB — no blocking lock / non-defaulted NOT NULL on a large table?

**Queue jobs / events changed:**
- Job idempotent and safe to retry? Failure mid-job handled?

Phrase each as a verb-first action with exactly what to run and what to verify.
