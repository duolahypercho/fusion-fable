#!/usr/bin/env bash
# save_run.sh — write the provenance .md for one Fusion run, on the INTERNAL disk only.
#
# Usage:
#   save_run.sh <slug> <question_file> <analysis_file> <final_file> [LABEL=path ...]
#
# - <slug>           : the panel slug actually run (e.g. opus4.8-gpt5.5-gemini3.1pro)
# - <question_file>  : the user's question, verbatim
# - <analysis_file>  : the judge's 5-section structured analysis
# - <final_file>     : the grounded final answer
# - LABEL=path       : one per panelist, raw answer file (e.g. "opus-A=/tmp/..._opusA.md",
#                      "gpt5.5=/tmp/fusion_codex_out.md", "gemini=/tmp/fusion_gemini_out.md")
#
# Optional env:
#   FUSION_PANEL_NOTE  degradation note (e.g. "gemini dropped: agy empty -> opus4.8-gpt5.5")
#   FUSION_ESTIMATE    the preflight estimate string, for the record
#
# Output: prints the path of the .md it wrote. Writes ONLY under ~/.claude/fusion-runs/
# (internal disk) — never ~/Projects or /Volumes/4T (the external 4T is TCC-blocked).

set -uo pipefail

slug="${1:?usage: save_run.sh <slug> <question_file> <analysis_file> <final_file> [LABEL=path ...]}"
question_file="${2:?need question_file}"
analysis_file="${3:?need analysis_file}"
final_file="${4:?need final_file}"
shift 4

RUNS_DIR="$HOME/.claude/fusion-runs"
mkdir -p "$RUNS_DIR"
ts="$(date +%Y-%m-%d_%H%M%S)"
out="$RUNS_DIR/${ts}_${slug}.md"

emit_file() {
  if [ -f "$1" ] && [ -s "$1" ]; then
    cat "$1"
    # guarantee a trailing newline so the next markdown block is never glued on
    [ -n "$(tail -c1 "$1")" ] && echo
  else
    echo "_(empty / not available)_"
  fi
}

{
  echo "# Fusion run — $ts"
  echo
  echo "- **Panel run** : \`$slug\`"
  [ -n "${FUSION_PANEL_NOTE:-}" ] && echo "- **Degradation** : ${FUSION_PANEL_NOTE}"
  [ -n "${FUSION_ESTIMATE:-}" ]   && echo "- **Estimate (preflight)** : ${FUSION_ESTIMATE}"
  echo
  echo "## Question (verbatim)"
  echo
  echo '```'
  emit_file "$question_file"
  echo '```'
  echo
  echo "## Raw panelist answers"
  if [ "$#" -eq 0 ]; then
    echo
    echo "_(no panelist provided)_"
  fi
  for spec in "$@"; do
    label="${spec%%=*}"
    path="${spec#*=}"
    echo
    echo "### $label"
    echo
    emit_file "$path"
    echo
  done
  echo "## Analysis (consensus / contradictions / partial coverage / unique insights / blind spots)"
  echo
  emit_file "$analysis_file"
  echo
  echo "## Final answer"
  echo
  emit_file "$final_file"
  echo
} > "$out"

echo "$out"
