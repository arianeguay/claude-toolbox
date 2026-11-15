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

- `start-issue`, `start-batch` — verification means actually driving a live
  Linear/GitHub/GitLab workspace end to end, not just reading the adapter markdown.
- `browser-test` — verification means driving a real browser.

Editing any of these skills' own markdown runs on any host, so it carries no `host:*`
label. Proving the skill actually drives the live system it targets needs the laptop
(`host:laptop`: a live tracker workspace logged in, a real browser). Everything else in this
repo runs anywhere.

**Test:** the evidence, not the edit: work that is writable anywhere but provable only on the
laptop gets `host:laptop`.
