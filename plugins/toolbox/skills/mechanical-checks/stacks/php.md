# Mechanical checks — PHP

Run against `$DIFF` when the diff touches `*.php`. **Extend per repo**; repo docs + linter config win.
(Universal checks U1–U3 run from SKILL.md.)

## C1 — Debug output left in (auto-fixable)
```bash
git diff "$DIFF" -- '*.php' | grep '^+' | grep -nE '\b(var_dump|print_r|dd|dump|error_log|var_export)\s*\('
```
Flag `var_dump`/`print_r`/`dd()`/`dump()`/`error_log` added in the diff. Use the repo's logger (PSR-3 / `Log::`). Auto-fixable: remove.

## C2 — Missing strict types where the repo uses it
```bash
# New .php files without declare(strict_types=1) when siblings have it
for f in $(git diff "$DIFF" --name-only --diff-filter=A | grep '\.php$'); do
  head -5 "$f" | grep -q 'declare(strict_types=1)' || echo "MISSING declare(strict_types=1) — $f"
done
```
Only flag if the repo's existing files declare strict types.

## C3 — `dd()` / `dump()` from framework debug helpers
Covered by C1, but specifically in Laravel these halt execution — never ship them. Auto-fixable.

## C4 — Wildcard / suppressed errors
```bash
git diff "$DIFF" -- '*.php' | grep '^+' | grep -nE '@[a-zA-Z_]+\(|error_reporting\(0\)'
```
Flag the `@` error-suppression operator and `error_reporting(0)` added in the diff.

## Verify after fixes
```bash
./vendor/bin/php-cs-fixer fix --dry-run   # or phpcs — substitute the repo's tool
./vendor/bin/phpstan analyse              # or psalm — if the repo static-analyzes
```
