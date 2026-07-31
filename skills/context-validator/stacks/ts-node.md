# Context validation — TypeScript + Node (no React)

When the diff touches `*.ts` in a non-React project. **Extend per repo.**

## Automated (I read the changed code and report)
- **Unhandled rejections** — `async` paths with no `try/catch` or `.catch`, awaited calls whose failure isn't handled.
- **Public API breaks** — changed signatures/return types on exported functions; a renamed/removed export that callers depend on (grep usages).
- **Resource leaks** — opened handles/streams/connections/timers without a close/clear on every path.
- **Config/env assumptions** — new required env vars not documented or defaulted.

## Targeted human questions
- **Backward compatibility** — if this is a published lib or a service contract, confirm existing consumers won't break (or that it's a versioned breaking change).
- **CLI / integration behavior** — anything only observable by running the tool end-to-end against real input.
- **Migration/runtime ordering** — if startup or data-shape ordering matters, confirm the real run.

Phrase each as a verb-first action with exactly what to run and what to verify.
