#!/usr/bin/env bash
# fusion-plan-nudge.sh — PreToolUse backstop for the Agent/Task tool.
#
# When the orchestrator is about to spawn a sub-agent for a NON-TRIVIAL implementation task, inject an
# advisory reminder to plan it first via `/fusion-plan --no-interview` (requirements from the story doc /
# current plan, never an interview). Advisory only: never blocks, never denies. Fail-open on any error.
#
# Wired in settings.local.json as a PreToolUse hook with matcher "Agent|Task".

input="$(cat 2>/dev/null)"
[ -z "$input" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0   # no jq -> no-op, never block

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
case "$tool" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

prompt="$(printf '%s' "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null)"
agent="$(printf '%s' "$input" | jq -r '.tool_input.agent_name // .tool_input.subagent_type // empty' 2>/dev/null)"
session="$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)"
[ -z "$prompt" ] && exit 0

# Skip fusion-plan's own Opus panelist spawns (they carry this marker) so we never self-trigger.
printf '%s' "$prompt" | grep -q '\[FUSION-PANELIST\]' && exit 0

low="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

# Only nudge when the delegation clearly involves implementation (English + Thai signals).
# Pure explore/research/review delegations have no implementation verb and are skipped.
impl_re='implement|build|create |write the|add (a|the|support|an)|fix |bug|refactor|migrat|wire up|integrat|เขียนโค้ด|เขียน code|สร้าง|แก้|ทำ feature|coding|รีแฟคเตอร์'
printf '%s' "$low" | grep -Eq "$impl_re" || exit 0

# Dedupe: nudge at most once per distinct task per session.
dir="${TMPDIR:-/tmp}/fusion-plan-nudge"
mkdir -p "$dir" 2>/dev/null
key="$(printf '%s|%s' "$agent" "$(printf '%s' "$prompt" | head -c 200)" | sha1sum 2>/dev/null | cut -d' ' -f1)"
marker="$dir/${session}.${key}"
if [ -n "$key" ]; then
  [ -f "$marker" ] && exit 0
  : > "$marker" 2>/dev/null
fi

msg='⟡ fusion-plan backstop: about to delegate an implementation task. If it is NON-TRIVIAL (real logic/architecture, "wrong is expensive") and not planned yet, FIRST run `/fusion-plan --no-interview` on it — derive requirements from the story doc / current plan, do NOT interview. Skip if the task is trivial or already planned.'

jq -n --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$ctx}}' 2>/dev/null
exit 0
