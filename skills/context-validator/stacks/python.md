# Context validation — Python

When the diff touches `*.py`. **Extend per repo.** Framework questions (migrations, Celery) only fire
when those files are present.

## Automated (I read the changed code and report)
- **N+1 trace** — ORM queries inside loops or serializer/`get_*` methods without a visible `select_related`/`prefetch_related`.
- **Public API breaks** — changed view/serializer fields, URL signatures, or response shapes that existing clients depend on.
- **Unguarded async** — `async`/`await` paths without error handling; blocking calls in async context.

## Targeted human questions (ask only the relevant sections)

**API / endpoints** (views/serializers/urls changed):
- Tested with a real HTTP client (not just unit tests), happy path end-to-end?
- Backward compatible — renamed/removed fields don't break existing clients?
- Auth/permissions — right user allowed, wrong user rejected?
- Error responses (400/403/404) consistent with the existing API?

**Models / migrations** (models or migrations changed):
- Forward migration applies cleanly locally?
- Backward migration tested, or documented as non-reversible?
- Safe on a populated prod DB — no `NOT NULL` without default on a large table, no long table lock?

**Celery tasks** (tasks/celery files changed):
- Idempotent — safe to replay if it runs twice?
- Failure mid-task handled? Retry logic doesn't create unwanted side effects?

**Signals / async** (signals/receivers or async added):
- No race condition if two events fire the handler simultaneously?
- Handlers don't run long synchronous queries (request-timeout risk)?

Phrase each as a verb-first action with exactly what to run and what to verify.
