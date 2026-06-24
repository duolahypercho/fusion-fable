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

# --- Voie W: Windows transcript capture (no PTY on this platform) ----------------------
# On Windows (MSYS/Git-Bash) there is no usable PTY: python lacks the `pty`/`termios`
# modules and `script` is absent, so voie A always yields empty stdout. agy DOES contact
# Gemini and writes the answer to its per-conversation transcript on disk. agy_capture.py
# runs the prompt in an isolated workspace dir and reads the MODEL response straight back
# out of that transcript. Use it directly here and skip voie A/B.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    cap_py="$SCRIPT_DIR/agy_capture.py"
    if have python && [ -f "$cap_py" ]; then
      # No --model: agy's configured default is already Gemini 3.1 Pro (High), and passing
      # --model in print mode can hang (see bug notes). Opt in via FUSION_AGY_FORCE_MODEL.
      AGY_MODEL="${FUSION_AGY_FORCE_MODEL:-}" \
      AGY_POLL_SECONDS="$FUSION_TIMEOUT" \
        python "$cap_py" "$(cat "$prompt_file")" > "$output_file" 2> "$scratch/stderr.log"
      if [ -s "$output_file" ]; then
        echo "[run_gemini.sh] ok (voie W: Windows transcript capture) -> $output_file"
        exit 0
      fi
      echo "[run_gemini.sh] voie W empty — falling through to voie A/B." >&2
      [ -s "$scratch/stderr.log" ] && tail -5 "$scratch/stderr.log" >&2
    fi
    ;;
esac

# --- Voie A: pseudo-TTY (survives socket stdio in cmux / headless) ---------------------
# agy bug #76 needs a real TTY on stdout. `script -q /dev/null` calls tcgetattr() on fd 0 and
# ABORTS when the orchestrator runs in a socket (cmux/headless: "tcgetattr/ioctl: Operation not
# supported on socket"), so agy never launches and voie A *and* voie B come back empty. Prefer a
# pty.fork()-based Python runner that gives the CHILD a fresh pty and never touches the parent's
# fd 0 termios; fall back to `script` only if python3 is missing (plain TTY contexts).
# sed strips ANSI (ESC[...m) and the literal "^D" caret-notation; tr removes residual control
# bytes (CR, etc.) while keeping tab + newline.
if have python3 && python3 -c 'import pty' 2>/dev/null; then
  pty_runner=( python3 "$SCRIPT_DIR/_pty_run.py" )
elif have script; then
  pty_runner=( script -q /dev/null )
else
  pty_runner=()
fi
orig_id="${ANTIGRAVITY_CONVERSATION_ID:-}"
unset ANTIGRAVITY_CONVERSATION_ID
export ANTIGRAVITY_AGENT=0

_run_with_timeout "$EXT_TIMEOUT" "${pty_runner[@]}" agy "${agy_args[@]}" < /dev/null \
  2> "$scratch/stderr.log" \
  | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\^D//g' \
  | LC_ALL=C tr -d '\000-\010\013-\037\177' > "$output_file"

# --- Voie B: transcript JSONL fallback ------------------------------------------------
if [ ! -s "$output_file" ]; then
  echo "[run_gemini.sh] voie A vide (bug #76 probable) — fallback transcript JSONL." >&2
  tr="$(find "$BRAIN_DIR" -name transcript.jsonl -newer "$ts_marker" -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null | awk -v oid="$orig_id" 'oid == "" || index($0, oid) == 0 {print; exit}')"
  if [ -n "$tr" ] && [ -s "$tr" ]; then
    if have jq; then
      jq -rs 'map(select(.source=="MODEL" and .status=="DONE" and .type=="PLANNER_RESPONSE"))
              | (last // {}) | .content // empty' "$tr" > "$output_file" 2>/dev/null
    elif have python3; then
      python3 -c '
import sys, json
ans = ""
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get("source") == "MODEL" and d.get("status") == "DONE" and d.get("type") == "PLANNER_RESPONSE":
            if "content" in d and d["content"]:
                ans = d["content"]
    except: pass
if ans:
    print(ans, end="")
' < "$tr" > "$output_file" 2>/dev/null
    fi
  fi
fi

# --- Anti-empty guard -----------------------------------------------------------------
if [ ! -s "$output_file" ]; then
  echo "[run_gemini.sh] agy produced no answer (voie A + voie B both empty). Dropping Gemini." >&2
  [ -s "$scratch/stderr.log" ] && { echo "[run_gemini.sh] agy stderr tail:" >&2; tail -10 "$scratch/stderr.log" >&2; }
  exit 1
fi
echo "[run_gemini.sh] ok -> $output_file"
