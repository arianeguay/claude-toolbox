# Stack baseline — TypeScript + React + Tailwind

Generic checklist of drift to look for in a TS/React/Tailwind codebase. **Extend per repo**;
the repo's own `CLAUDE.md`/`AGENTS.md` and sibling files always win over this baseline.

## Reuse before inventing
- Before a new hook/util/component: grep `src/` for verbs (`format`, `parse`, `build`, `get`, `use`, `from`, `to`) + the entity noun + sibling files in the same folder.
- A component/util used **once** is a candidate to inline — flag premature abstraction.
- Before a new entity-display lookup (name/label/icon by id), check for an existing display component/map; reuse it instead of inlining the lookup.

## Components
- Match the repo's component form — function declaration vs `React.FC`. Check what siblings use; don't introduce the other.
- Props interface naming: match the repo (commonly `<ComponentName>Props`, never bare `Props`).
- Wrapper that just forwards props with one tweak → inline the tweak.

## State & data
- Server data → the repo's data layer (React Query / SWR / RTK Query) — don't fetch ad hoc.
- Global UI state → the repo's chosen store (Zustand / Redux / context). Don't add a new state lib for one component; `useState` if it's local.
- Forms → the repo's form lib (react-hook-form, etc.) + its validation idiom.

## Styling
- Prefer Tailwind utilities (or whatever the repo standardized on) over inline styles / new CSS modules.
- Use the repo's class-merge helper (`cn`, `clsx`, `tailwind-merge`) — don't string-concat classNames.
- Design tokens / theme values over raw hex/px. Reuse existing button/tag/badge variants over new ones.
- If the repo enforces sorted Tailwind classes (Biome / prettier-plugin-tailwindcss), run its autofix.

## Conventions
- Imports: absolute (`tsconfig` paths) vs relative — match the repo config; no deep relative chains if aliases exist.
- `const` over `let`; name id collections by what they hold (`orderIds`, not `customerIds`, when they're order ids).
- i18n: if the repo has locale files, never add a key to one locale only — keep all locales in sync.

## Design / layout
- Match comparable surfaces: action-button placement, dialog/drawer footer order, list-row density, empty-state shape, column/field order. Cite the comparable surface (file:line) when flagging.

## Verify commands (substitute the repo's actual scripts)
```bash
npm run check       # or: biome check / eslint + prettier
npm run type-check  # or: tsc --noEmit
npm test <file>     # if the touched file has a test
```
