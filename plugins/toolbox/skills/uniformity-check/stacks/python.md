# Stack baseline — Python

Generic checklist of drift for a Python codebase (Django, FastAPI, library, scripts).
**Extend per repo**; the repo's `CLAUDE.md`/`AGENTS.md` and sibling files win over this baseline.

## Reuse before inventing
- Before a new function: grep the package for verbs (`parse`, `build`, `get`, `load`, `serialize`, `to_`, `from_`) + the entity noun + siblings in the same module.
- Check installed deps (`pyproject.toml` / `requirements.txt`) — the capability may already exist. Don't hand-roll what a present dep provides.
- A helper used once → candidate to inline.

## Framework idioms
- Match the repo's framework patterns rather than inventing: Django (ORM queries, managers, `select_related`/`prefetch_related`, DRF serializers/viewsets, migrations), FastAPI (dependency injection, Pydantic models, routers). Reuse existing serializers/validators/managers.
- ORM: avoid N+1 — match how siblings batch queries. New queries should be team/tenant-scoped like the neighbours if the repo scopes data.

## Errors, logging, config
- Errors: match the repo's exception hierarchy and raising style; don't introduce a parallel error type.
- Logging: use the `logging` module / the repo's logger, never `print()` in library/app code.
- Config/settings: access via the repo's settings module, not scattered `os.environ`.

## Conventions
- Typing: match the repo's type-hint coverage; reuse shared type aliases.
- Naming: `snake_case` functions/vars, `PascalCase` classes, `UPPER_SNAKE` constants.
- Imports: follow the repo's grouping/ordering (isort/ruff). Absolute vs relative — match the package.
- Data models/validation: reuse the repo's schema layer (Pydantic / DRF / dataclasses) rather than ad-hoc dicts.

## Verify commands (substitute the repo's actual tools)
```bash
ruff check .        # or: flake8
mypy .              # or: pyright — if the repo type-checks
pytest <path>       # if the touched code has a test; match the repo's runner/flags
```
