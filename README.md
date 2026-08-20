# claude-toolbox

**Instance-agnostic** Claude Code skills — the ones that are useful in *any* project, not
tied to a specific codebase or employer. This repo is a **Claude Code plugin marketplace**:
it ships one plugin, `toolbox`, containing every skill here plus the worktree/skill-safety
hooks. Sync across machines is `/plugin marketplace update`.

> Project-coupled skills don't belong here — they live with their project. The bar for
> inclusion is: *would this still make sense on a brand-new machine, in a project Claude
> has never seen?* Anything project-specific is a field in `PROFILE.md`, not a hardcoded
> value in a skill.

## Contents

```text
.claude-plugin/
  marketplace.json     # marketplace catalog (lists the `toolbox` plugin)
  plugin.json          # the `toolbox` plugin manifest (name, version)
skills/
  git-clean-history/   # rewrite messy git history into a clean, senior-level log (git-only)
  clean-worktree/      # remove stale worktrees/branches after squash-merge (via [gone] upstream)
  fix-ci/              # diagnose + fix CI failures (GitLab/GitHub, multi-toolchain)
  smallest-footprint/  # audit a PR/MR diff and reduce its surface area
  mechanical-checks/   # pre-review scan for mechanical violations (per-stack checks in stacks/)
  context-validator/   # judgment-level pre-review: scope + code-path analysis, then a precise human action list
  comment-audit/       # audit changed-file comments (noise/stale/missing/over-doc) before merge
  merge-parent/        # merge the parent/default branch into current, w/ mechanical anti-drop check on conflicts
  mr-description/      # generate/update a PR/MR title + description from the diff (gh/glab)
  review-comments-resolver/ # resolve human + bot (CodeRabbit/Bugbot) review comments (gh/glab)
  mr-ship/             # orchestrator: the pre-review pipeline at three depths (full/medium/short)
  uniformity-check/    # check a diff for drift vs the codebase (per-stack baselines in stacks/)
  browser-test/        # drive a browser for UI validation (DevTools MCP / Playwright MCP / playwright-cli)
  am-i-stuck/          # Shape Up hill-chart / "am I in the tunnel?" self-diagnostic
  what-did-we-learn/   # end-of-session capture of generalizable learnings into memory
  issues-candidate/    # end-of-task sweep for follow-up work worth filing (trackers/ per host)
  is-it-down/          # check live status of gitlab/github/anthropic/etc via their status-page APIs
  plan/                # code-anchored implementation plan, bridging shaping decisions to build
  start-issue/         # bare issue link → branch/worktree, In Progress, build, PR, In Review (trackers/ per host)
hooks/
  hooks.json           # SessionStart/PreToolUse/PostToolUse wiring (paths via ${CLAUDE_PLUGIN_ROOT})
  guard-skill-deletion.sh          # PreToolUse(Bash) — stub, see Hooks below
  symlink-worktree-local-config.sh # SessionStart + PostToolUse(Bash) — stub, see Hooks below
PROFILE.example.md     # per-project settings the skills read (copy to PROFILE.md)
```

## Install

Add the marketplace once, then install the plugin:

```text
/plugin marketplace add arianeguay/claude-toolbox
/plugin install toolbox@claude-toolbox
```

Skills are namespaced under the plugin: `/toolbox:mr-ship`, `/toolbox:fix-ci`, etc.
The hooks activate automatically when the plugin is enabled — no manual copy step.

## Configure

Copy `PROFILE.example.md` to `PROFILE.md` — in the repo you're working in, or in
`~/.claude/` for machine-wide defaults — and fill in what applies: ticket prefix, lint and
type-check commands, app URL, shaping directory.

Every field is optional. A skill that can't find its field falls back to detection, or
skips the step and says so. None of them guess, and none of them read credentials —
`browser-test` asks for a login rather than reading one from a file.

`PROFILE.md` is gitignored here so a filled-in copy never gets published by accident.

## The ship pipeline

`mr-ship` runs at three depths. The axis is how much human judgment the run involves:

| Mode | Covers | Human actions |
|---|---|---|
| **short** | Mechanical and objective only | 0 |
| **medium** | + diff hygiene (footprint, uniformity, comments) | ≤2 |
| **full** | + scope validation and deep review | ≤5 |

`/mr-ship short` picks a mode explicitly. With no argument it suggests one from the diff
size and whether a PR/MR already exists, prints the reason, and lets you override.

Rough guide: **full** for a complex new PR · **medium** for a simpler one, or a delta on a
PR that already passed a full run · **short** for a trivial PR, or the final gate before
flipping draft to ready.

## Sync across machines

The repo is the source of truth. To ship a change everywhere:

1. Commit + push to `main`.
2. Bump `version` in `.claude-plugin/plugin.json` (users only receive updates when it changes).
3. On each machine: `/plugin marketplace update` — Claude Code refetches the plugin.

## Add a skill

1. Drop a `skills/<name>/SKILL.md` (and any support files) into the repo.
2. Commit + push, bump `plugin.json` version.
3. Other machines: `/plugin marketplace update`. The skill appears as `/toolbox:<name>`.

Keep it instance-agnostic: no employer names, no internal hostnames, no credentials, no
hardcoded branch names. Project-specific values belong in `PROFILE.md`.

## Develop locally (live edit)

To iterate on a skill or hook without publishing, load the repo directly — this bypasses
the marketplace and picks up working-tree edits (run `/reload-plugins` after changes):

```bash
claude --plugin-dir /path/to/claude-toolbox
```

## Hooks

`hooks/hooks.json` wires two hooks, resolved against `${CLAUDE_PLUGIN_ROOT}`:

- `guard-skill-deletion.sh` — PreToolUse(Bash), intended to block accidental skill deletion.
- `symlink-worktree-local-config.sh` — SessionStart + PostToolUse(Bash), intended to link
  local config into git worktrees.

> **Both are currently pass-through stubs** — they install cleanly and do nothing. Neither
> guards nor symlinks anything yet. Implement them, then bump the plugin version.
