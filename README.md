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
  am-i-stuck/          # Shape Up hill-chart / "am I in the tunnel?" self-diagnostic
  what-did-we-learn/   # end-of-session capture of generalizable learnings into memory
  peon-ping-config/    # configure peon-ping sound notifications
  peon-ping-toggle/    # mute/unmute peon-ping sounds mid-session
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
