---
name: model-router
description: Toggle a per-turn nudge that suggests the best Claude model (Fable/Sonnet/Haiku) for the task in the current prompt. Use when the user says "/model-router", "/model-router on|off|status", "toggle model router", "enable model suggestions", or asks why a model nudge keeps/doesn't appear. Does NOT switch the model itself — Claude Code locks the model in at session start, so this only ever nudges; the dropdown switch stays manual.
user-invocable: true
---

# model-router

State lives in a flag file (`~/.claude/.model-router-active`), toggled by the
`model-router-nudge.sh` UserPromptSubmit hook — not by this skill. The hook
already handled the mechanical part before this skill loaded. Your job here is
just to relay the outcome.

## What actually happened

The hook parses the raw prompt on every turn, before you see it:

- `/model-router on` / `off` / `status` (with or without a `toolbox:` prefix) →
  hook writes/clears the flag file and injects a one-line confirmation as
  `additionalContext`. **Relay that line to the user, one sentence, nothing
  added.**
- Any other prompt, while the flag is on → hook ran a cheap Haiku
  classification of the task and, only if the suggestion changed since the
  last turn, injected `Model Router suggests: <model> for this task. ...`.
  Work it into your reply in one short clause — don't make it its own
  paragraph, don't repeat it if you already mentioned it seconds ago.

If no `additionalContext` about the router shows up, the hook had nothing to
say (already off, prompt too short to classify, or no suggestion change) —
don't invent a status line.

## Bare invocation with no hook context

If you're reading this file but the hook didn't inject anything (e.g. `jq` or
`claude` isn't on PATH, so the hook silently no-op'd), check the flag file
yourself and report state plainly:

```bash
[ -f ~/.claude/.model-router-active ] && echo ON || echo OFF
```

## What this is and isn't

- **Is:** a reminder, so you stop forgetting to switch models per task.
- **Isn't:** automatic model switching. No hook — this one included — can
  change the model of an already-running session; `--model` only applies at
  process launch, and `/model` is the only thing that works mid-session. That
  still has to be a manual click on the model dropdown.
- **Cost:** one Haiku call per turn while on, only when the prompt is ≥8
  chars — roughly $0.0003-0.0005/call, plus a few seconds of latency. Free to
  leave on; the latency is the real tradeoff.
- **Scope:** the flag is global (`~/.claude`), not per-project — toggling it
  once applies everywhere until toggled back.

## Usage

```
/model-router on       # start nudging
/model-router off       # stop
/model-router status    # check without changing anything
/model-router           # same as status, plus the usage line
```
