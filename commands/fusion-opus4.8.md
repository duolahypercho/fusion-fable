---
description: Fusion panel of two independent Opus 4.8 runs, judged by Opus 4.8 (opus4.8-4.8)
argument-hint: <your question>
---
Invoke the **fusion** skill on the task below, forcing the `opus4.8-4.8` panel:
run the same prompt twice as TWO independent Opus 4.8 panelists (Agent subagents, in parallel, neither
seeing the other's work) → Opus 4.8 judges both answers → Opus writes the final answer grounded in the
analysis.

Follow the skill's SKILL.md exactly (fan out in parallel → judge → grounded final answer) and present the
standard sections (Consensus / Contradictions / Partial coverage / Unique insights / Blind spots / Final
answer). Do NOT add a GPT-5.5 or Gemini panelist, even if codex/gemini are installed — this command is
pinned to the pure-Opus panel. Do not assign the two runs any "lenses" — pass the task verbatim to both.

Task: $ARGUMENTS
