# Stack baseline — PHP

Generic checklist of drift for a PHP codebase (Laravel, Symfony, WordPress, or plain PHP).
**Extend per repo**; the repo's `CLAUDE.md`/`AGENTS.md`, `composer.json`, and sibling files win over this baseline.

## Reuse before inventing
- Before a new helper/class: grep `src/`/`app/` for verbs (`format`, `parse`, `build`, `get`, `make`, `from`, `to`) + the entity noun + siblings in the same namespace.
- Check `composer.json` — the capability may already be provided by a package (HTTP, dates via Carbon, collections, validation, UUID). Don't hand-roll what a required dep does.
- A class/method used once → candidate to inline or fold.

## Framework idioms
- Match the repo's framework patterns rather than inventing: Laravel (Eloquent queries, form requests, resources, service providers, artisan migrations, facades vs DI), Symfony (services, autowiring, doctrine repositories, attributes/annotations). Reuse existing models/repositories/validators.
- DB: use the repo's query layer (Eloquent / Doctrine / query builder) with **bound parameters** — never string-concatenate SQL. Avoid N+1; eager-load like the neighbours (`with()` / `fetchJoinCollection`).
- Templating: match the repo's engine (Blade / Twig / plain PHP) — don't mix.

## Errors, logging, config
- Errors: throw typed exceptions matching the repo's hierarchy; don't `return false`/`null` where siblings throw.
- Logging: use the repo's logger (PSR-3 / Monolog / `Log::` facade), never `echo`/`var_dump`/`error_log` in app code.
- Config/secrets: read via the repo's config/env layer (`config()`, `$_ENV` through a config object), not scattered `getenv()`.

## Conventions
- Coding style: follow **PSR-12** (and PSR-1) unless the repo's linter says otherwise; autoloading is **PSR-4** (namespace ↔ path). Match existing namespacing.
- Types: `declare(strict_types=1);` if the repo does; use parameter/return type hints and property types consistently with siblings.
- Naming: `PascalCase` classes, `camelCase` methods/vars, `UPPER_SNAKE` constants.
- Validation/serialization: reuse the repo's form-request / DTO / resource layer rather than ad-hoc array munging.

## Verify commands (substitute the repo's actual tools)
```bash
composer run lint      # or: ./vendor/bin/php-cs-fixer fix --dry-run / phpcs
./vendor/bin/phpstan analyse   # or: psalm — if the repo static-analyzes
./vendor/bin/phpunit <path>    # or: php artisan test — if the touched code has a test
```
