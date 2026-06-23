# Mechanical checks — Python

Run against `$DIFF` when the diff touches `*.py`. **Extend per repo**; repo docs + linter config win.
(Universal checks U1–U3 run from SKILL.md.) Framework checks (migrations, Celery) auto-skip when absent.

## C1 — print() left in app code (auto-fixable)
```bash
git diff "$DIFF" -- '*.py' | grep '^+' | grep -n 'print(' | grep -v '#' | grep -vi 'test'
```
Flag added `print(` outside tests/comments. Use the `logging` module instead. Auto-fixable: remove.

## C2 — Wildcard imports (auto-fixable)
```bash
git diff "$DIFF" -- '*.py' | grep '^+' | grep -E 'from .* import \*'
```
Flag `from x import *` — import explicitly.

## C3 — Missing migration (Django; only if models changed)
```bash
CHANGED_APPS=$(git diff "$DIFF" --name-only | grep -E 'models(/|\.py)' | sed -E 's|/models.*||;s|/models\.py||' | sort -u)
for app in $CHANGED_APPS; do
  git diff "$DIFF" --name-only | grep -q "$app/migrations/" || echo "MISSING migration? — $app models changed, no migration in diff"
done
```
**Warning, not blocker** — false positive if the model change doesn't touch the schema (added method/property). Verify with `makemigrations --check --dry-run` if available.

## C4 — N+1 query patterns (heuristic → warning)
```bash
git diff "$DIFF" -- '*.py' | grep -A2 '^+.*for .* in ' | grep -E '\.objects\.|\.filter\(|\.get\('   # query in a loop
git diff "$DIFF" -- '*.py' | grep '^+' | grep 'def get_' | grep -A5 'objects\.'                      # serializer method query
```
Flag ORM queries inside loops or serializer methods without a visible `select_related`/`prefetch_related`. Heuristic — treat as a warning.

## C5 — Celery task pitfalls (only if tasks/celery files changed)
```bash
git diff "$DIFF" -- '*.py' | grep '^+' | grep -E '@app\.task|@shared_task' | grep -v 'bind=True'   # self.retry needs bind=True
git diff "$DIFF" -- '*.py' | grep '^+' | grep 'self\.retry'                                          # retry without max_retries
```
Flag `self.retry` without `bind=True`, and `autoretry_for` without `max_retries` (infinite-retry risk).

## Verify after fixes
```bash
ruff check .        # or flake8 — substitute the repo's tool
mypy .              # if the repo type-checks
```
