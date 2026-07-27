---
description: Browser automation for visual testing and UI validation using playwright-cli
allowed-tools: Bash
---

# playwright-cli — UI Testing

Use `playwright-cli` (NOT MCP, NOT npx playwright) for all browser tasks.

## Authentication

The local dev server requires login. Use these credentials:
- **Username:** `pw_test`
- **Password:** `montofu123`

After opening the browser, log in before navigating:
```bash
playwright-cli -s=noether open http://localhost:3000 --headed
# Fill login form
playwright-cli -s=noether snapshot           # find username/password field refs
playwright-cli -s=noether fill <user_ref> "pw_test"
playwright-cli -s=noether fill <pass_ref> "montofu123"
playwright-cli -s=noether click <submit_ref> # click the login button
```

## Basic Workflow
```bash
playwright-cli -s=noether open http://localhost:3000 --headed
# (log in first — see Authentication above)
playwright-cli -s=noether snapshot
playwright-cli -s=noether screenshot --filename=/tmp/pw-screenshots/before.png
```

## Useful Commands
- `open <url>` — open the browser
- `snapshot` — generate a YAML of elements (saved to disk, not in context)
- `screenshot [--filename=path]` — screenshot saved to disk
- `click <ref>` — click an element by ref (e.g., e21)
- `fill <ref> "value"` — fill a field
- `goto <url>` — navigate to a URL
- `close` — close the session

## Important noether URLs
- Calendar RadOnc  : /scheduling/radonc
- Calendar MedOnc  : /scheduling/medonc
- Calendar Diagnostics : /scheduling/diagnostics
- Bulk edit flow   : navigate via the UI (bulk edit button in the calendar header)

## Test Preconditions by Feature

### Worklists
Before testing any worklist view, ensure **"Afficher les tâches accomplies"** (Show completed tasks) is **unchecked**.
If this toggle is on, completed tasks appear in results and will skew what you're validating.
```bash
# After navigating to the worklist page, take a snapshot to locate the toggle
playwright-cli -s=noether snapshot
# Find the toggle ref and verify it's off; if not, uncheck it before proceeding
playwright-cli -s=noether click <toggle_ref>
```

## When to use playwright-cli vs Vitest
- **playwright-cli** : visual validation, CSS/layout regression, multi-step flows, Blueprint states (tags, badges, disabled)
- **Vitest** : business logic, Redux state, hooks, callbacks, conditional renders

## Visual Regression
1. `screenshot --filename=/tmp/pw-screenshots/before.png` before changes
2. Make your changes
3. `screenshot --filename=/tmp/pw-screenshots/after.png`
4. Compare visually or ask Claude to analyze both images

## Flows with Async State (Redux / React Query)
After any interaction that triggers a Redux re-render or React Query mutation,
take the screenshot at the next step — `playwright-cli` naturally waits for the next
stable state before executing the following command:
```bash
playwright-cli -s=noether click e21          # e.g., save an appointment
playwright-cli -s=noether screenshot --filename=/tmp/pw-screenshots/after-save.png
```

## Snapshot for Validating Blueprint Components
The YAML snapshot is useful for inspecting Blueprint element states without relying
solely on visuals (e.g., disabled button, tag color, badge present):
```bash
playwright-cli -s=noether snapshot
# Then ask: "in the snapshot, is the Save button disabled?"
```

## Named Sessions
Always use `-s=noether` to keep the browser open between commands.

## Screenshots
All files are saved to disk — they do NOT enter context automatically.
To analyze them: explicitly ask "look at /tmp/pw-screenshots/after.png".

---

### Usage in Claude Code

Start a Claude Code session in `noether`, then:
```
/pw-test
Open localhost:3000, navigate to the bulk edit flow, take a screenshot at each step
```