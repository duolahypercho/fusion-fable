#!/usr/bin/env bash
# preflight.sh — pre-run, NON-BLOCKING sanity check the orchestrator shows before fanning out.
#
# Usage:
#   preflight.sh <slug> <prompt_file>
#
# Prints: a rough token/call estimate (so a heavy question doesn't surprise you) and a Codex
# cap reminder. It NEVER blocks — it only informs. Always exits 0.

set -uo pipefail

slug="${1:?usage: preflight.sh <slug> <prompt_file>}"
prompt_file="${2:?usage: preflight.sh <slug> <prompt_file>}"

case "$slug" in
  opus4.8-gpt5.5-gemini3.1pro) n=3 ;;
  opus4.8-gpt5.5|opus4.8-gemini3.1pro|opus4.8-4.8)  n=2 ;;
  *)                           n=2 ;;
esac

words=0
[ -f "$prompt_file" ] && words="$(wc -w < "$prompt_file" | tr -d ' ')"
# ~1.3 tokens/word, very rough; output usually dwarfs input on deep questions.
in_tokens=$(( words * 4 / 3 ))

echo "preflight (informational — not a gate):"
echo "  panel        : $slug  ($n panelists + 1 Opus judge pass)"
echo "  prompt size  : ~${words} words (~${in_tokens} input tokens) sent to EACH of $n panelists"
echo "  note         : each panelist also generates a full answer, and the judge reads all $n;"
echo "                 real token cost is several× the input. Heavy deep-research questions are slow."
echo "  per-panelist timeout : ${FUSION_TIMEOUT:-300}s (override with FUSION_TIMEOUT)"

if command -v codex >/dev/null 2>&1; then
  echo "  codex (GPT-5.5) : installed — quota isn't readable non-interactively; if a run fails on"
  echo "                    cap, check '/status' inside codex. Panel degrades gracefully if it does."
else
  echo "  codex (GPT-5.5) : NOT installed — GPT-5.5 panelist will be skipped."
fi

exit 0
