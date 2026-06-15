#!/usr/bin/env bash
# run_gemini.sh — run one Gemini 3.1 Pro panelist (via the `agy` / Antigravity CLI), web + bash.
#
# Usage:
#   run_gemini.sh <prompt_file> <output_file>
#
# Why this is not a plain `agy -p ... > out`:
# agy bug #76 — in print mode (`-p`) with no TTY attached, agy exits 0 but writes an EMPTY
# stdout. So a naive capture silently yields nothing. This script neutralises that with two
# independent paths plus a hard anti-empty guard:
#
#   Voie A (primary)  : run agy under a pseudo-TTY (`script -q /dev/null ...`) so print mode
#                       behaves as if interactive, strip ANSI/CR, capture stdout.
#   Voie B (fallback) : if voie A is empty, read the answer back from agy's own transcript
#                       JSONL (the last MODEL/DONE/PLANNER_RESPONSE record's .content).
#   Anti-empty guard  : if both are empty, print to stderr and exit 1 — NEVER exit 0 empty.
#                       The orchestrator then drops Gemini and degrades the panel.
#
# Config (env):
#   AGY_MODEL            model name (default "Gemini 3.1 Pro (High)"; see `agy models`).
#   FUSION_AGY_NO_MODEL  set to 1 to omit --model and use agy's configured default
#                        (escape hatch if --model ever hangs in print mode).
#   FUSION_TIMEOUT       per-panelist budget in seconds (default 300, from _fusion_lib.sh).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_fusion_lib.sh"

prompt_file="${1:?usage: run_gemini.sh <prompt_file> <output_file>}"
output_file="${2:?usage: run_gemini.sh <prompt_file> <output_file>}"

AGY_MODEL="${AGY_MODEL:-Gemini 3.1 Pro (High)}"
BRAIN_DIR="$HOME/.gemini/antigravity-cli/brain"
# agy's own print-mode deadline (Go duration); keep the external backstop a bit longer
# so agy stops itself cleanly first.
AGY_PRINT_TIMEOUT="${FUSION_TIMEOUT}s"
EXT_TIMEOUT=$((FUSION_TIMEOUT + 30))

if ! have agy; then
  echo "[run_gemini.sh] agy CLI not installed — skip this panelist." >&2
  exit 127
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/fusion-gemini.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
ts_marker="$scratch/.t"; : > "$ts_marker"   # everything agy writes after this is "newer"

# Assemble agy args (model is opt-out via FUSION_AGY_NO_MODEL).
agy_args=( -p "$(cat "$prompt_file")" --dangerously-skip-permissions --print-timeout "$AGY_PRINT_TIMEOUT" )
if [ -z "${FUSION_AGY_NO_MODEL:-}" ] && [ -n "$AGY_MODEL" ]; then
  agy_args+=( --model "$AGY_MODEL" )
fi

# --- Voie A: pseudo-TTY ---------------------------------------------------------------
# sed strips ANSI colour sequences (ESC[...m) and the literal "^D" caret-notation that
# macOS `script` echoes for the EOF; tr removes any remaining raw control bytes a pty
# leaves behind (CR, etc.) while keeping tab + newline.
_run_with_timeout "$EXT_TIMEOUT" script -q /dev/null agy "${agy_args[@]}" \
  2> "$scratch/stderr.log" \
  | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\^D//g' \
  | LC_ALL=C tr -d '\000-\010\013-\037\177' > "$output_file"

# --- Voie B: transcript JSONL fallback ------------------------------------------------
if [ ! -s "$output_file" ]; then
  echo "[run_gemini.sh] voie A vide (bug #76 probable) — fallback transcript JSONL." >&2
  tr="$(find "$BRAIN_DIR" -name transcript.jsonl -newer "$ts_marker" -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null | head -1)"
  if [ -n "$tr" ] && [ -s "$tr" ]; then
    jq -rs 'map(select(.source=="MODEL" and .status=="DONE" and .type=="PLANNER_RESPONSE"))
            | (last // {}) | .content // empty' "$tr" > "$output_file" 2>/dev/null
  fi
fi

# --- Anti-empty guard -----------------------------------------------------------------
if [ ! -s "$output_file" ]; then
  echo "[run_gemini.sh] agy produced no answer (voie A + voie B both empty). Dropping Gemini." >&2
  [ -s "$scratch/stderr.log" ] && { echo "[run_gemini.sh] agy stderr tail:" >&2; tail -10 "$scratch/stderr.log" >&2; }
  exit 1
fi
echo "[run_gemini.sh] ok -> $output_file"
