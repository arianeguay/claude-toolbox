---
name: browser-test
description: Drive a browser to validate UI — visual checks, layout/CSS regression, multi-step flows, console/network inspection. Picks the right tool for the job (Chrome DevTools MCP, Playwright MCP, or playwright-cli for recordings). Use when asked to "check the UI", "screenshot the page", "test the flow in the browser", "why does this look wrong", or to verify a visual change before review.
user-invocable: true
---

# Browser Test

Validate UI in a real browser. Three tools can do this and they are not interchangeable — pick from the table, don't default to whichever you used last.

## Tool selection

| You need | Tool | Why |
|---|---|---|
| A **video**, a replayable trace, or an artifact to attach to a PR/MR | `playwright-cli` | The only one that records |
| To **debug a live page** — console errors, network calls, computed CSS, performance | **Chrome DevTools MCP** ← *default* | Real Chrome, real devtools protocol |
| **Deterministic, reproducible** automation; isolated state; cross-browser | Playwright MCP | Accessibility-tree snapshots, clean contexts |
| Chrome unavailable (headless, CI, container) | Playwright MCP | Fallback |

The short version: **video → `playwright-cli`; otherwise Chrome DevTools MCP; otherwise Playwright MCP.**

Name the tool and the reason in one line before starting: `Chrome DevTools MCP — inspecting computed styles on a live page`. If the chosen tool isn't available, fall down the table and say so; never silently substitute.

## When browser testing is the wrong tool

- Business logic, state management, hooks, callbacks, conditional renders → unit tests
- Anything a unit test can assert deterministically → unit test, every time

Browser testing is for what you can only see: layout, CSS, visual regression, multi-step flows, component states that depend on real rendering.

---

## Setup

The app URL and any dev credentials are project-specific. Read them from `PROFILE.md` (`APP_URL`, and the auth section if the dev server requires login). If neither the profile nor the user provides them, ask once — **never guess a URL and never hardcode credentials into this skill or any file in the repo.**

---

## Core workflow

1. **Baseline** — navigate, wait for a stable state, screenshot
2. **Act** — make the change, or perform the interaction
3. **Compare** — screenshot again, diff visually

Save screenshots to a path **inside the repo working tree** (e.g. `.screenshots/before.png`). Chrome DevTools MCP enforces a workspace-root restriction — writes to `/tmp` or an external scratchpad are rejected.

Screenshots are written to disk; they do **not** enter context automatically. To analyze one, explicitly read it.

## Async state (Redux / React Query / any async render)

After an interaction that triggers a re-render or a mutation, take the screenshot **as the next step** — the tooling waits for the next stable state before running the following command. Screenshotting in the same step as the click captures the pre-update frame.

## Inspecting component state without relying on pixels

For questions like "is the Save button disabled?", "does the tag have the right variant?", "is the badge present?" — take a structural snapshot (accessibility tree or DOM query) instead of squinting at an image. More reliable, and it survives a restyle.

## Test preconditions

Any view with filters, toggles, or saved user state needs its preconditions stated before assertions mean anything — a "show completed items" toggle left on will silently skew what you're validating. Establish the precondition explicitly, then assert.

---

## Reporting

State what you checked, what you saw, and what you could not verify. A screenshot is evidence, not a conclusion — say what in it supports the claim. If a check was inconclusive (flaky render, missing fixture data), say so rather than reporting a pass.
