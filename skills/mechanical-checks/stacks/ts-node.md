# Mechanical checks — TypeScript + Node (no React)

Run against `$DIFF` when the diff touches `*.ts` in a non-React project. **Extend per repo**;
repo docs + linter config win. (Universal checks U1–U3 run from SKILL.md.)

## C1 — Debug statements (auto-fixable)
```bash
git diff "$DIFF" -- '*.ts' '*.js' | grep '^+' | grep -nE '\bconsole\.(log|debug)\(|\bdebugger\b'
```
Flag `console.log`/`debugger`. If the repo has a logger, `console.*` in app code is a finding regardless of level.

## C2 — Relative imports where the repo uses absolute
```bash
git diff "$DIFF" -- '*.ts' | grep '^+' | grep "from ['\"]\.\./"
```
Flag `../../x` when `tsconfig.json` defines path aliases / `imports`. Auto-fixable.

## C3 — Wildcard / barrel re-export sprawl
```bash
git diff "$DIFF" -- '*.ts' | grep '^+' | grep -E "export \* from|import \* as"
```
Flag new `export *` barrels if the repo prefers explicit exports (check siblings).

## C4 — `.only` / focused tests left in
```bash
git diff "$DIFF" -- '*.ts' | grep '^+' | grep -E '\b(describe|it|test)\.only\('
```
Flag `.only` — it silently skips the rest of the suite in CI. Auto-fixable: drop `.only`.

## Verify after fixes
```bash
npm run lint && npm run type-check     # substitute the repo's actual scripts
```
