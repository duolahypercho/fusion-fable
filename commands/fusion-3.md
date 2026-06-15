---
description: Fusion full panel — Opus 4.8 + GPT-5.5 + Gemini 3.1 Pro in parallel, judged by Opus 4.8 (opus4.8-gpt5.5-gemini3.1pro)
argument-hint: <your question>
---
Invoke the **fusion** skill on the task below, forcing the richest panel `opus4.8-gpt5.5-gemini3.1pro`:
Opus 4.8 (Agent subagent), GPT-5.5 (via `codex exec`), and Gemini 3.1 Pro (via `agy`, pseudo-TTY) answer
the SAME prompt IN PARALLEL, each independently with web + bash and none seeing the others' work → Opus 4.8
judges all three → Opus writes the final answer grounded in the analysis.

Follow the skill's SKILL.md exactly (preflight → fan out in parallel → judge adopting
`references/fable_synthesizer.md` → grounded final answer → save provenance). Present the standard sections
(Consensus / Contradictions / Couverture partielle / Insights uniques / Angles morts / Réponse finale).
Pass the task verbatim to all three; no "lenses". Three families, one of each — do not add a second Opus run.

This command targets the FULL panel but degrades gracefully: if `codex` or `agy` is missing or a panelist
fails/times out, drop it, note the degraded panel in the output, and finish with what remains
(`opus4.8-gpt5.5`, then ultimately `opus4.8-4.8`) rather than aborting.

Task: $ARGUMENTS
