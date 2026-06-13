---
name: fusion
description: >-
  Answer a hard question by fanning it out to a PANEL of models running in parallel — each answering
  independently with web search and bash, none seeing the others' work — then having Opus 4.8 judge every
  response into a structured analysis (consensus, contradictions, partial coverage, unique insights, blind
  spots) and write a final answer grounded in it. The panel is two independent Opus 4.8 runs (slug
  opus4.8-4.8), Opus 4.8 + GPT-5.5 via codex (opus4.8-gpt5.5), or those plus Gemini 3.1 Pro
  (opus4.8-gpt5.5-gemini3.1pro). Opus always judges and writes the final answer — the pipeline can't be
  reversed. Use this whenever the user asks to "run it through Fusion", wants a multi-model / panel /
  ensemble answer, wants a question cross-checked across models, or wants a higher-confidence answer with
  consensus and blind spots surfaced — even if they don't say "fusion". Best for high-stakes research,
  design calls, and debugging where being confidently wrong is expensive.
---

# Fusion

Fusion turns one prompt into a panel. The question goes to several models **at the same time**, each
answering independently — with web search and bash, and with no knowledge of the others. Then Opus 4.8
reads every answer, extracts the structure of the panel's reasoning (what they agree on, where they
conflict, what only one saw, what they all missed), and writes a final answer grounded in that analysis.

The whole mechanism is **independence, then synthesis**. The diversity that makes a panel beat a single
model is harvested, not manufactured: running the same prompt independently yields different reasoning
paths, tool calls, and sources — even two cold runs of the *same* model diverge enough that synthesizing
them beats running it once. So there are no assigned "lenses" or personas; every panelist gets the user's
task verbatim and answers it straight. (See `references/panel.md`.)

**One hard rule: Opus 4.8 always judges and writes the final answer — the pipeline can't be reversed.**
The panelist models can't call back out to spawn Opus, so Opus is always the driver. The slug reads
driver-first for that reason.

## Step 0 — Pick the panel

```bash
bash <skill_dir>/scripts/detect_panel.sh
```

It prints a `SLUG=` line recommending the richest panel possible on this machine:

| Slug | Panel | Requires |
| --- | --- | --- |
| `opus4.8-4.8` | the same prompt run twice as 2 independent Opus 4.8 panelists | nothing — always available |
| `opus4.8-gpt5.5` | Opus 4.8 + GPT-5.5 in parallel | `codex` CLI |
| `opus4.8-gpt5.5-gemini3.1pro` | Opus 4.8 + GPT-5.5 + Gemini 3.1 Pro in parallel | `codex` + `gemini` CLIs |

If the user named a slug, honor it — but if a required CLI is missing, say so, drop that panelist, and
fall back to the next-richest panel rather than failing. Otherwise use the detector's recommendation.

## Step 1 — Fan out, in parallel and blind

Read `references/panel.md`. Build each panelist's prompt as the user's task **verbatim** plus the short
instruction to research with web + bash and return a complete, self-contained answer as one of several
independent experts who won't see the others' work. Do not assign lenses; do not pre-digest the task.

Launch **all panelists in a single turn** so they run concurrently:

- **Opus 4.8 panelist(s)** → the `Agent` tool, `subagent_type: general-purpose` (web + bash built in).
  For `opus4.8-4.8`, spawn **two** independent Opus subagents with the *same* prompt — two cold runs.
  Spawn them in the same message so they run at once; each returned answer is one panel response.
- **GPT-5.5 panelist** → write its prompt to a temp file and run in the background:
  ```bash
  bash <skill_dir>/scripts/run_codex.sh /tmp/fusion_codex_prompt.txt /tmp/fusion_codex_out.md medium
  ```
  `-o` makes codex write only its final answer to the out file; read it once it finishes.
- **Gemini panelist** → `bash <skill_dir>/scripts/run_gemini.sh /tmp/fusion_gemini_prompt.txt /tmp/fusion_gemini_out.md`.
  Exit 127 means the CLI isn't installed — drop Gemini and note the panel downgraded.

Keep panelists isolated: never paste one panelist's output into another's prompt. The orchestrator (you)
is the judge and must stay separate from the panelists — for `opus4.8-4.8`, both panelists are spawned
subagents, not you, so your synthesis reads all answers fresh.

## Step 2 — Judge

Once every panelist has returned, read `references/judge_rubric.md`. Read all responses in full, attribute
claims to each panelist (by model / run), and produce the five-section analysis: **Consensus**,
**Contradictions**, **Partial coverage**, **Unique insights**, **Blind spots**. Don't average or smooth
over conflict — independent agreement is your highest-confidence signal, and honest disagreement is the
most useful thing the panel produces. A panelist that ran the code or read a primary source outranks one
reasoning from memory, regardless of model.

## Step 3 — Final answer, grounded in the analysis

Write the actual answer to the user's task, grounded in the structured analysis — lead with the
high-confidence consensus, fold in unique insights, flag what stays uncertain. The final answer must
follow *from* the synthesis, not be one panelist's answer lightly edited.

## Step 4 — Present

Lead with the **final answer**, then the structured analysis beneath it as the audit trail. Name the panel
slug you ran and which panelists participated. If the panel downgraded because a CLI was missing, say so
and how to enable the fuller panel (install the missing CLI).

## Cost & latency note

A panel costs roughly N× a single answer in tokens and runs as slow as its slowest panelist. That's the
deliberate trade: you spend more to stop being confidently wrong where that's expensive. For quick or
low-stakes questions, a single direct answer is the right call — don't reach for Fusion when one model
would obviously do.
