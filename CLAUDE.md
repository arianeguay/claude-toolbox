# claude-toolbox

## Where a Task Runs

`plugins/toolbox/` is markdown skills with no build, no test suite, and no credentials of
its own — most changes here are provable in a web sandbox: read the skill, edit it, verify
against local git state (a throwaway bare repo, `git log`, `git worktree list`). That
covers even git-heavy fixes: a stacked-branch or squash-merge repro reproduces with plain
`git` and no remote host, credentials, or paid run.

The exception is a skill whose verification means driving something *live* that a web
sandbox cannot reach or fake: a real tracker workspace, a real remote host account, or a
real browser.

- `start-issue`, `start-milestone` — verification means actually driving a live
  Linear/GitHub/GitLab workspace end to end, not just reading the adapter markdown.
- `browser-test` — verification means driving a real browser.
- `is-it-down` — verification means hitting real external status-page APIs.

Editing any of these skills' own markdown is `claude:web`; proving the skill actually
drives the live system it targets is `claude:local`. Everything else in this repo defaults
to `claude:web`.

**Test:** writable on web but unprovable there means `claude:local`.
