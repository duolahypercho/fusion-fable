---
description: Fusion panel of Opus 4.8 + GPT-5.5 in parallel, judged by Opus 4.8 (opus4.8-gpt5.5)
argument-hint: <your question>
---
Invoke the **fusion** skill on the task below, forcing the `opus4.8-gpt5.5` panel:
Opus 4.8 (Agent subagent) and GPT-5.5 (via `codex exec`) answer the SAME prompt IN PARALLEL, each
independently with web + bash and neither seeing the other's work → Opus 4.8 judges both answers → Opus
writes the final answer grounded in the analysis.

Follow the skill's SKILL.md exactly (fan out in parallel → judge → grounded final answer) and present the
standard sections (Consensus / Contradictions / Partial coverage / Unique insights / Blind spots / Final
answer). Use exactly one Opus 4.8 panelist and one GPT-5.5 panelist — do not add a Gemini panelist or a
second Opus run. Pass the task verbatim to both; no "lenses". If the `codex` CLI is not installed, stop and
say so rather than silently downgrading to the opus4.8-4.8 panel.

Task: $ARGUMENTS
