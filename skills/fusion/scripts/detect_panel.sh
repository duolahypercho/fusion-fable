#!/usr/bin/env bash
# detect_panel.sh — figure out which panelist CLIs are installed and recommend a Fusion panel.
#
# Fusion fans a prompt out to a panel of models in parallel, then Opus 4.8 judges. Opus 4.8 is always
# available as a panelist via the Agent tool (in-process subagents) and is always the judge — so it never
# needs a CLI check. This script only probes the *external* panelist CLIs (GPT-5.5 via codex, Gemini via
# gemini) and prints the richest panel the machine can currently support.
#
# Output: human-readable lines + a final `SLUG=...` line the orchestrator can grep.

have() { command -v "$1" >/dev/null 2>&1; }

codex_ok=false; gemini_ok=false
have codex  && codex_ok=true
have gemini && gemini_ok=true

echo "panelist availability (Opus 4.8 is always a panelist + the judge, via Agent subagents):"
echo "  opus4.8  : yes (Agent subagents — always available)"
printf "  gpt5.5   : %s (codex CLI)\n"  "$([ "$codex_ok"  = true ] && echo yes || echo NO)"
printf "  gemini3.1pro : %s (gemini CLI)\n" "$([ "$gemini_ok" = true ] && echo yes || echo NO)"
echo

if   $codex_ok && $gemini_ok; then slug="opus4.8-gpt5.5-gemini3.1pro"
elif $codex_ok;                then slug="opus4.8-gpt5.5"
else                                slug="opus4.8-4.8"
fi

echo "recommended panel: $slug"
echo "SLUG=$slug"
