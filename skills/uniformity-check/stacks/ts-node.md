# Stack baseline — TypeScript + Node (no React)

Generic checklist of drift for a TS/Node codebase (CLI, server, library). **Extend per repo**;
the repo's `CLAUDE.md`/`AGENTS.md` and sibling files win over this baseline.

## Reuse before inventing
- Before a new helper: grep `src/`/`lib/` for verbs (`parse`, `format`, `build`, `load`, `from`, `to`) + the entity noun + siblings in the same module.
- Check `package.json` deps — the capability may already be provided by a library the repo uses (date, validation, http, fs). Don't hand-roll what a present dep does.
- A function exported but used once → candidate to inline.

## Module & API shape
- Match the repo's module system (ESM vs CJS) and `import`/`require` style — don't mix.
- Follow the repo's public-API surface convention (barrel `index.ts` vs direct imports).
- Match the framework idioms in use (Express/Fastify middleware shape, dependency injection, route registration) instead of a new pattern.

## Errors, logging, config
- Error handling: match the repo's posture — thrown errors vs `Result`/either, error classes vs plain `Error`. Don't introduce a second style.
- Logging: use the repo's logger (pino/winston/etc.), not `console.log`, if one exists.
- Config/env: access via the repo's config module, not scattered `process.env` reads.
- Async: match promises/async-await vs callbacks; don't reintroduce callbacks in a promise codebase.

## Conventions
- Imports: absolute (`tsconfig` paths / `paths`) vs relative — match repo config.
- `const` over `let`; precise names; explicit return types if the repo does that.
- Validation: reuse the repo's schema lib (zod/yup/io-ts) rather than ad-hoc type guards.

## Verify commands (substitute the repo's actual scripts)
```bash
npm run lint        # or: biome check / eslint
npm run type-check  # or: tsc --noEmit
npm test <file>     # if the touched file has a test
```
