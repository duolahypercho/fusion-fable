#!/usr/bin/env bash
# install.sh — install the Fusion-Fable skill + slash commands into your Claude Code config.
#
# Copies:
#   skills/fusion        -> $CLAUDE_DIR/skills/fusion
#   commands/*.md         -> $CLAUDE_DIR/commands/
# where CLAUDE_DIR defaults to ~/.claude (override with CLAUDE_CONFIG_DIR).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands"

rm -rf "$CLAUDE_DIR/skills/fusion"
cp -R "$HERE/skills/fusion" "$CLAUDE_DIR/skills/fusion"
cp "$HERE/commands/"*.md "$CLAUDE_DIR/commands/"
chmod +x "$CLAUDE_DIR/skills/fusion/scripts/"*.sh

echo "✓ Installed Fusion-Fable into $CLAUDE_DIR"
echo "    skill    : $CLAUDE_DIR/skills/fusion"
echo "    commands : /fusion-opus4.8  /fusion-gpt5.5"
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
if have gemini; then
  echo "  opus4.8-gpt5.5-gemini3.1pro  : ready (gemini found)"
else
  echo "  opus4.8-gpt5.5-gemini3.1pro  : needs the 'gemini' CLI (install + log in for Gemini 3.1 Pro)"
fi
echo
echo "Next: restart Claude Code (or run /reload-skills) so 'fusion' and the slash commands load."
