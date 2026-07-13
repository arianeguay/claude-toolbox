# claude-toolbox

Personal, **instance-agnostic** Claude Code skills — the ones that are useful in *any*
project, not tied to a specific codebase or employer. This repo is the source of truth;
`install.sh` symlinks each skill into `~/.claude/skills/`, so edits here are live immediately.

> Project-coupled skills (GrayOS / noether / nabla, MR pipelines, hospital personas, etc.)
> do **not** belong here — they live with their project. The bar for inclusion is:
> *would this still make sense on a brand-new machine, in a project Claude has never seen?*

## Contents

```text
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
install.sh             # symlink every skills/* into ~/.claude/skills (idempotent)
```

## Install (any machine)

```bash
git clone git@github.com:<user>/claude-toolbox.git ~/dev/claude-toolbox
cd ~/dev/claude-toolbox && ./install.sh
```

`install.sh` auto-discovers every directory under `skills/` — no list to maintain.
It refuses to clobber a real (non-symlink) skill of the same name; pass `--force` to
back it up first, or `--uninstall` to remove only the symlinks this repo created.

## Add a skill

1. Drop a `skills/<name>/SKILL.md` (and any support files) into the repo.
2. `./install.sh` (picks up the new dir automatically).
3. Commit + push. Other machines: `git pull` — symlinks already point at the live dir.

## Sync across machines

The repo is the source of truth. On each machine: `git pull` to receive, `git push` to
share. No copy step — the symlinks track the working tree.

## Config templates

`configs/settings.json` and `configs/known_marketplaces.json` are cleaned copies of
`~/.claude/settings.json` and `~/.claude/plugins/known_marketplaces.json` — stripped of
machine-specific junk (marketplace `installLocation`/`lastUpdated`, and personal/local-only
tool hooks like peon-ping and agent-flow, same exclusion bar as skills above).

Not auto-installed — copy manually and reconcile:
- `settings.json` hook paths use `$HOME` as a placeholder; the two referenced scripts
  (`guard-skill-deletion.sh`, `symlink-worktree-local-config.sh`) must exist at
  `~/.claude/hooks/` on the target machine — they aren't part of this repo.
- `known_marketplaces.json` — Claude Code regenerates `installLocation`/`lastUpdated`
  on next marketplace refresh; just needs `source` to re-add each marketplace.
