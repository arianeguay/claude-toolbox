#!/usr/bin/env bash
# UserPromptSubmit hook: optional per-turn "which model fits this task" nudge.
#
# Off by default — toggle with `/model-router on|off|status`. State lives in a
# flag file so it persists across sessions/projects without touching CLAUDE.md
# or settings.json (no hook can actually switch the running model — Claude
# Code locks it in at session start — so this only ever nudges; the model
# dropdown switch stays manual).
#
# MODEL_ROUTER_CLASSIFYING guards against the classify sub-call below (itself
# a `claude -p` invocation) re-triggering this same hook and recursing.
set -euo pipefail

[[ -z "${MODEL_ROUTER_CLASSIFYING:-}" ]] || exit 0

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
flag_path="$claude_dir/.model-router-active"

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
[[ -n "$prompt" ]] || exit 0

trimmed=$(printf '%s' "$prompt" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')
lower=$(printf '%s' "$trimmed" | tr '[:upper:]' '[:lower:]')

# --- toggle commands: /model-router [on|off|status] ---------------------
if [[ "$lower" =~ ^/(toolbox:)?model-router($|\ ) ]]; then
  arg=$(printf '%s' "$lower" | awk '{print $2}')
  mkdir -p "$claude_dir"
  case "$arg" in
    on)
      echo "on" > "$flag_path"
      msg="Model Router: ON. Nudges once per changed suggestion; you still switch models via the dropdown yourself."
      ;;
    off)
      rm -f "$flag_path"
      msg="Model Router: OFF."
      ;;
    status)
      if [[ -f "$flag_path" ]]; then msg="Model Router: ON."; else msg="Model Router: OFF."; fi
      ;;
    "")
      if [[ -f "$flag_path" ]]; then state="ON"; else state="OFF"; fi
      msg="Model Router: $state. Usage: /model-router on|off|status"
      ;;
    *)
      msg="Model Router: unknown option '$arg'. Use on, off, or status."
      ;;
  esac
  jq -n --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
  exit 0
fi

# --- nudge, only while on -------------------------------------------------
[[ -f "$flag_path" ]] || exit 0
[[ ${#trimmed} -ge 8 ]] || exit 0
command -v claude >/dev/null 2>&1 || exit 0

scratch=$(printf '%s' "$input" | jq -r '.scratchpad_dir // empty' 2>/dev/null || true)
session=$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null || true)
track_file="${scratch:-/tmp}/model-router-last-${session}"

choice=$(MODEL_ROUTER_CLASSIFYING=1 claude -p --model claude-haiku-4-5-20251001 \
  "Classify this coding task's ideal Claude model. Reply with exactly one word, no formatting: fable, sonnet, or haiku.
Task: ${trimmed:0:500}" </dev/null 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z') || exit 0

# Substring match, not equality — tolerates the model padding its answer
# with stray words despite the "one word" instruction.
case "$choice" in
  *fable*)  choice=fable;  label="Fable 5.1 (heavy reasoning / long-horizon agentic work)" ;;
  *haiku*)  choice=haiku;  label="Haiku 4.5 (fast, cheap)" ;;
  *sonnet*) choice=sonnet; label="Sonnet 5 (default)" ;;
  *) exit 0 ;;
esac

prev=$(cat "$track_file" 2>/dev/null || true)
[[ "$choice" != "$prev" ]] || exit 0
echo "$choice" > "$track_file"

jq -n --arg ctx "Model Router suggests: $label for this task. Mention it briefly; switching models is still a manual dropdown action." \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
