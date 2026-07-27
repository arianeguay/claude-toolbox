# claude-toolbox

Personal, **instance-agnostic** Claude Code skills — the ones that are useful in *any*
project, not tied to a specific codebase or employer. This repo is a **Claude Code plugin
marketplace**: it ships one plugin, `toolbox`, containing every skill here plus the
worktree/skill-safety hooks. Sync across machines is `/plugin marketplace update`.

> Project-coupled skills (GrayOS / noether / nabla, MR pipelines, hospital personas, etc.)
> do **not** belong here — they live with their project. The bar for inclusion is:
> *would this still make sense on a brand-new machine, in a project Claude has never seen?*

## Contents

```text
.claude-plugin/
  marketplace.json     # marketplace catalog (lists the `toolbox` plugin)
  plugin.json          # the `toolbox` plugin manifest (name, version)
skills/
  git-clean-history/   # rewrite messy git history into a clean, senior-level log (git-only)
  clean-worktree/      # remove stale worktrees/branches after squash-merge (via [gone] upstream)
  fix-ci/              # diagnose + fix CI failures (GitLab/GitHub, multi-toolchain)
  smallest-footprint/  # audit a MR/PR diff and reduce its surface area
  mechanical-checks/   # pre-review scan for mechanical violations (per-stack checks in stacks/)
  context-validator/   # judgment-level pre-review: scope + code-path analysis, then a precise human action list
  comment-audit/       # audit changed-file comments (noise/stale/missing/over-doc) before merge
  merge-parent/        # merge the parent/default branch into current, w/ mechanical anti-drop check on conflicts
  mr-description/      # generate/update a PR/MR title + description from the diff (gh/glab)
  review-comments-resolver/ # resolve human + bot (CodeRabbit/Bugbot) review comments (gh/glab)
  mr-ship/             # orchestrator: runs the pre-review pipeline (calls the skills below in order)
  uniformity-check/    # check a diff for drift vs the codebase (per-stack baselines in stacks/)
  am-i-stuck/          # Shape Up hill-chart / "am I in the tunnel?" self-diagnostic
  what-did-we-learn/   # end-of-session capture of generalizable learnings into memory
  is-it-down/          # check live status of gitlab/github/anthropic/etc via their status-page APIs
  plan/                # code-anchored implementation plan, bridging shaping decisions to build
  pw-test/             # browser automation for visual testing and UI validation (playwright-cli)
  mr-go/               # check a draft MR/PR is ready to flip to ready-for-review
hooks/
  hooks.json           # SessionStart/PreToolUse/PostToolUse wiring (paths via ${CLAUDE_PLUGIN_ROOT})
  guard-skill-deletion.sh          # PreToolUse(Bash) — block accidental skill deletion
  symlink-worktree-local-config.sh # SessionStart + PostToolUse(Bash) — link local config into worktrees
CLAUDE.md              # portable personal working-style template (see below)
```

## Install (any machine)

Add the marketplace once, then install the plugin:

```text
/plugin marketplace add arianeguay/claude-toolbox
/plugin install toolbox@claude-toolbox
```

Skills are namespaced under the plugin: `/toolbox:mr-ship`, `/toolbox:fix-ci`, etc.
The hooks activate automatically when the plugin is enabled — no manual copy step.

## Sync across machines

The repo is the source of truth. To ship a change everywhere:

1. Commit + push to `main`.
2. Bump `version` in `.claude-plugin/plugin.json` (users only receive updates when it changes).
3. On each machine: `/plugin marketplace update` — Claude Code refetches the plugin.

## Add a skill

1. Drop a `skills/<name>/SKILL.md` (and any support files) into the repo.
2. Commit + push, bump `plugin.json` version.
3. Other machines: `/plugin marketplace update`. The skill appears as `/toolbox:<name>`.

## Develop locally (live edit)

To iterate on a skill or hook without publishing, load the repo directly — this bypasses
the marketplace and picks up working-tree edits (run `/reload-plugins` after changes):

```bash
claude --plugin-dir /path/to/claude-toolbox
```

## Hooks

`hooks/hooks.json` wires three hooks, resolved against `${CLAUDE_PLUGIN_ROOT}`:

- `guard-skill-deletion.sh` — PreToolUse(Bash), blocks accidental skill deletion.
- `symlink-worktree-local-config.sh` — SessionStart + PostToolUse(Bash), links local
  config into git worktrees.

> `symlink-worktree-local-config.sh` is currently a **pass-through stub** (installs
> cleanly, no-op). Paste the real body from your main machine's `~/.claude/hooks/`,
> commit, and bump the plugin version. `guard-skill-deletion.sh` is live.

## Config templates

`configs/settings.json` and `configs/known_marketplaces.json` are cleaned copies of
`~/.claude/settings.json` and `~/.claude/plugins/known_marketplaces.json` — stripped of
machine-specific junk. Hooks are no longer templated here; they ship with the plugin.

Not auto-installed — copy manually and reconcile:
- `settings.json` — `statusLine`, `model`, `effortLevel`, and `enabledPlugins` are personal
  defaults; merge what you want. This `toolbox` marketplace/plugin is added via the
  `/plugin` commands above, not through this file.
- `known_marketplaces.json` — the *external* marketplaces this setup consumes; Claude Code
  regenerates `installLocation`/`lastUpdated` on next refresh, so only `source` matters.

## Personal CLAUDE.md template

`CLAUDE.md` at repo root is the instance-agnostic slice of how I like to work —
collaboration style, code philosophy, git conventions, trade-off presentation, language
rule. No employer/team/project content lives here.

Not auto-installed (a plugin can't write your global `~/.claude/CLAUDE.md`, and that file
on a machine already set up for a job may carry company-specific context that shouldn't be
clobbered): copy or merge it into `~/.claude/CLAUDE.md` by hand, then add company/project
specifics on top of it.
