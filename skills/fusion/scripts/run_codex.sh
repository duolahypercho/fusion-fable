#!/usr/bin/env bash
# run_codex.sh — run one GPT-5.5 panelist (via codex) on a prompt, with web search + bash.
#
# Usage:
#   run_codex.sh <prompt_file> <output_file> [reasoning_effort]
#
# - <prompt_file>   : path to a file containing the FULL panelist prompt (verbatim user task + brief instruction)
# - <output_file>   : where the panelist's final answer is written (clean, just the answer)
# - reasoning_effort: low | medium | high   (default: medium)
#
# Notes:
# - `-o/--output-last-message` writes ONLY the agent's final message — no streaming noise to parse.
# - `-s workspace-write` lets the panelist run shell commands in an isolated scratch dir (the "bash tool").
# - `-c tools.web_search=true` enables the web search tool.
# - We run in a throwaway scratch dir so a panelist's file writes never touch your repo.

set -uo pipefail

prompt_file="${1:?usage: run_codex.sh <prompt_file> <output_file> [reasoning_effort]}"
output_file="${2:?usage: run_codex.sh <prompt_file> <output_file> [reasoning_effort]}"
effort="${3:-medium}"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/fusion-codex.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

codex exec \
  --skip-git-repo-check \
  --cd "$scratch" \
  -s workspace-write \
  -c tools.web_search=true \
  -c "model_reasoning_effort=$effort" \
  -o "$output_file" \
  - < "$prompt_file" \
  > "$scratch/stream.log" 2>&1

status=$?
if [ $status -ne 0 ] || [ ! -s "$output_file" ]; then
  echo "[run_codex.sh] codex exited $status; tail of log:" >&2
  tail -20 "$scratch/stream.log" >&2
  exit 1
fi
echo "[run_codex.sh] ok -> $output_file"
