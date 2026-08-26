#!/usr/bin/env bash
# UserPromptSubmit hook: when a prompt is *nothing but* a tracker issue reference,
# remind the model that this means "run the start-issue skill end to end".
#
# The reminder is conditional on purpose — the hook can't tell a bare link from a
# link inside a real instruction, so it states the condition and leaves the call to
# the model. The length gate below is what keeps it off ordinary prompts that merely
# mention a ticket key.
set -euo pipefail

prompt=$(cat | jq -r '.prompt // empty' 2>/dev/null) || exit 0
[ -n "$prompt" ] || exit 0

ref=$(printf '%s' "$prompt" | grep -oiEm1 \
  'https?://(linear\.app/[^[:space:]]+/issue/[A-Za-z]+-[0-9]+|(www\.)?github\.com/[^[:space:]]+/issues/[0-9]+|[^[:space:]]*gitlab[^[:space:]]*/-/issues/[0-9]+)|\b[A-Z]{2,}-[0-9]+\b') || exit 0

# "Bare" = the reference plus at most a few words ("start this", "commence ça").
rest=$(printf '%s' "$prompt" | sed "s|${ref//|/\\|}||" | tr -d '[:space:]')
[ "${#rest}" -le 40 ] || exit 0

cat <<CTX
The prompt is a bare tracker issue reference ($ref) with no other instruction. That
means: run the \`start-issue\` skill end to end — read the issue, create the worktree on
the tracker's branch name, move it to In Progress, build it, open the PR, move it to In
Review. Don't ask between steps; the only stop is the plan confirmation on a complex issue.
CTX
