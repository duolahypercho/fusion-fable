#!/usr/bin/env bash
# install.sh — install the Fusion-Fable skill + slash commands into your Claude Code config.
#
# Copies:
#   skills/fusion        -> $CLAUDE_DIR/skills/fusion
#   skills/fusion-plan   -> $CLAUDE_DIR/skills/fusion-plan
#   commands/*.md         -> $CLAUDE_DIR/commands/
#   hooks/*.sh            -> $CLAUDE_DIR/hooks/   (optional backstop, NOT auto-enabled)
# where CLAUDE_DIR defaults to ~/.claude (override with CLAUDE_CONFIG_DIR).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands"

rm -rf "$CLAUDE_DIR/skills/fusion"
cp -R "$HERE/skills/fusion" "$CLAUDE_DIR/skills/fusion"
rm -rf "$CLAUDE_DIR/skills/fusion-plan"
cp -R "$HERE/skills/fusion-plan" "$CLAUDE_DIR/skills/fusion-plan"
cp "$HERE/commands/"*.md "$CLAUDE_DIR/commands/"
chmod +x "$CLAUDE_DIR/skills/fusion/scripts/"*.sh

# Optional backstop hook: copied so it's available, but NOT auto-enabled. Opt in via settings (see README).
if [ -d "$HERE/hooks" ]; then
  mkdir -p "$CLAUDE_DIR/hooks"
  cp "$HERE/hooks/"*.sh "$CLAUDE_DIR/hooks/" 2>/dev/null || true
  chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true
fi

echo "✓ Installed Fusion-Fable into $CLAUDE_DIR"
echo "    skills   : $CLAUDE_DIR/skills/fusion , $CLAUDE_DIR/skills/fusion-plan"
echo "    commands : /fusion-opus4.8  /fusion-gpt5.5  /fusion-3  /fusion-plan"
echo

# Report which chains are usable on this machine.
have() { command -v "$1" >/dev/null 2>&1; }
echo "Panel availability here:"
echo "  opus4.8-4.8                  : ready (two independent Opus 4.8 runs, judged by Opus — no external CLI)"
if have codex; then
  echo "  opus4.8-gpt5.5               : ready (codex found: $(codex --version 2>/dev/null | head -1))"
else
  echo "  opus4.8-gpt5.5               : needs the 'codex' CLI (install + log in for GPT-5.5)"
fi
if have agy; then
  echo "  opus4.8-gpt5.5-gemini3.1pro  : ready (agy found: $(agy --version 2>/dev/null | head -1))"
else
  echo "  opus4.8-gpt5.5-gemini3.1pro  : needs the 'agy' CLI (Antigravity; install + seed its keyring for Gemini 3.1 Pro)"
fi
echo
echo "/fusion-plan (OMC-integrated iterative planning):"
echo "  - INTERACTIVE (you type /fusion-plan): runs an OMC interview first (auto-chains 'omc-plan'), then"
echo "    deepens with the 3-round opus4.8-gpt5.5 panel and writes a concise plan to .omc/plans/."
echo "  - NON-INTERACTIVE (autonomous run / inside a sub-agent / --no-interview): no interview; derives"
echo "    requirements from the existing story doc / plan context."
echo "  - Best with oh-my-claudecode (OMC) installed; without OMC it falls back to a minimal inline interview."
echo
if [ -f "$CLAUDE_DIR/hooks/fusion-plan-nudge.sh" ]; then
  echo "Optional backstop hook installed (NOT enabled): $CLAUDE_DIR/hooks/fusion-plan-nudge.sh"
  echo "  To enable, add this to settings.json (or .claude/settings.local.json) and restart Claude Code:"
  echo '    {"hooks":{"PreToolUse":[{"matcher":"Agent|Task","hooks":[{"type":"command",'
  echo "      \"command\":\"bash $CLAUDE_DIR/hooks/fusion-plan-nudge.sh\"}]}]}}"
  echo "  It nudges you to /fusion-plan --no-interview before delegating a non-trivial implementation task."
  echo
fi
echo "Next: restart Claude Code (or run /reload-skills) so the skills and slash commands load."
