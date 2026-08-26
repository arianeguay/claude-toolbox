# Context validation — TypeScript + React + Tailwind

What to analyze automatically and what to ask the human, when the diff touches `*.tsx`/`*.ts`.
**Extend per repo.**

## Automated (I read the changed hooks/components and report)
- **Effect loops** — `useEffect`/`useCallback`/`useMemo` whose dep array includes a value the effect itself updates, or a new object/array literal recreated each render.
- **Race conditions** — multiple async calls (`useQuery`/`await`/`.then`) where a later response can overwrite a newer one; missing `enabled`/abort/cleanup.
- **Undefined-data paths** — UI that reads `data.x` on a path where `data` can still be `undefined`/loading; missing empty/loading state that would flash.
- **Stale closures** — event handlers capturing a value that won't update.
- **Visual (optional)** — if a browser-automation tool is available and the dev server responds (`curl -s -o /dev/null -w '%{http_code}' http://localhost:3000`), screenshot the routes the diff affects and check for obvious layout breaks. If not, skip and note it.

## Targeted human questions (only what code-reading can't settle)
- **Role / persona visibility** — if the feature is gated to a role/route, confirm it shows where intended and is hidden where not.
- **Real interaction** — drag/drop, focus/keyboard flow, or anything needing a genuine click-through.
- **Responsive** — if layout/spacing changed, confirm at a narrow width.

Phrase each as a verb-first action with the exact URL + what to verify (see SKILL.md Step 5).
