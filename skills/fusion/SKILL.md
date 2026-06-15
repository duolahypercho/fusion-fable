---
name: fusion
description: >-
  Answer a hard question by fanning it out to a PANEL of models running in parallel — each answering
  independently with web search and bash, none seeing the others' work — then having Opus 4.8 judge every
  response into a structured analysis (consensus, contradictions, partial coverage, unique insights, blind
  spots) and write a final answer grounded in it. The panel is two independent Opus 4.8 runs (slug
  opus4.8-4.8), Opus 4.8 + GPT-5.5 via codex (opus4.8-gpt5.5), or those plus Gemini 3.1 Pro via agy
  (opus4.8-gpt5.5-gemini3.1pro). Opus always judges and writes the final answer — the pipeline can't be
  reversed. Runs on local CLI subscriptions (no metered API), saves a timestamped provenance .md per run,
  and answers in French by default. Use this whenever the user asks to "run it through Fusion", says
  /fusion, wants a multi-model / panel / ensemble answer, wants a question cross-checked across models, or
  wants a higher-confidence answer with consensus and blind spots surfaced — even if they don't say
  "fusion". General-purpose: any topic (research, law, strategy, technical, personal). Best for high-stakes
  research, design calls, and debugging where being confidently wrong is expensive.
---

# Fusion

Fusion turns one prompt into a panel. The question goes to several models **at the same time**, each
answering independently — with web search and bash, and with no knowledge of the others. Then Opus 4.8
(this very session — the orchestrator) reads every answer, extracts the structure of the panel's reasoning
(what they agree on, where they conflict, what only one saw, what they all missed), and writes a final
answer grounded in that analysis.

The whole mechanism is **independence, then synthesis**. The diversity that makes a panel beat a single
model is harvested, not manufactured: running the same prompt independently yields different reasoning
paths, tool calls, and sources. So there are **no assigned "lenses" or personas** — every panelist gets the
user's task **verbatim** and answers it straight. (See `references/panel.md`.)

**One hard rule: Opus 4.8 always judges and writes the final answer — the pipeline can't be reversed.** The
panelist models can't call back out to spawn Opus, so Opus is always the driver. The slug reads
driver-first for that reason.

Throughout, `<skill_dir>` is the directory containing this SKILL.md (when installed:
`~/.claude/skills/fusion`). Write the user's question **verbatim** to `/tmp/fusion_question.txt` first —
several steps reuse it.

## Step 0 — Pick the panel

```bash
bash <skill_dir>/scripts/detect_panel.sh
```

It prints a `SLUG=` line recommending the richest panel possible on this machine:

| Slug | Panel | Requires |
| --- | --- | --- |
| `opus4.8-4.8` | the same prompt run twice as 2 independent Opus 4.8 panelists | nothing — always available |
| `opus4.8-gpt5.5` | Opus 4.8 + GPT-5.5 in parallel | `codex` CLI |
| `opus4.8-gpt5.5-gemini3.1pro` | Opus 4.8 + GPT-5.5 + Gemini 3.1 Pro in parallel | `codex` + `agy` CLIs |

If the user named a slug (or used a pinned `/fusion-*` command), honor it — but if a required CLI is
missing, say so, drop that panelist, and fall back to the next-richest panel rather than failing. Otherwise
use the detector's recommendation.

## Step 1 — Preflight (informational, never a gate)

```bash
bash <skill_dir>/scripts/preflight.sh <SLUG> /tmp/fusion_question.txt
```

Show its output to the user (rough token/call estimate + Codex cap reminder), then proceed. It never
blocks. Each panelist is bounded by a per-panelist timeout (`FUSION_TIMEOUT`, default 300s) baked into the
runners; raise it for heavy deep-research questions (`FUSION_TIMEOUT=600 bash <skill_dir>/scripts/...`).

## Step 2 — Fan out, in parallel and blind

Read `references/panel.md`. Build each panelist's prompt as the user's task **verbatim** plus the short
instruction to research with web + bash and return a complete, self-contained answer as one of several
independent experts who won't see the others' work. Do **not** assign lenses; do **not** pre-digest the
task. (Answer language: match the user's question; default to French if ambiguous.)

Launch **all panelists in a single turn** so they run concurrently:

- **Opus 4.8 panelist(s)** → the `Agent` tool, `subagent_type: general-purpose` (web + bash built in).
  For `opus4.8-4.8`, spawn **two** independent Opus subagents with the *same* prompt — two cold runs.
  Spawn them in the same message so they run at once. When each returns, write its answer to a temp file
  for provenance: `/tmp/fusion_opusA.md` (and `/tmp/fusion_opusB.md` for the second Opus run).
- **GPT-5.5 panelist** (if slug includes it) → write its prompt to a temp file, then run:
  ```bash
  bash <skill_dir>/scripts/run_codex.sh /tmp/fusion_codex_prompt.txt /tmp/fusion_codex_out.md medium
  ```
  `-o` makes codex write only its final answer to the out file. Exit 124 = timed out; any non-zero exit =
  drop GPT-5.5 and note the panel downgraded.
- **Gemini panelist** (if slug includes it) → write its prompt to a temp file, then run:
  ```bash
  bash <skill_dir>/scripts/run_gemini.sh /tmp/fusion_gemini_prompt.txt /tmp/fusion_gemini_out.md
  ```
  This calls `agy` under a pseudo-TTY (working around agy bug #76) with a transcript-JSONL fallback and a
  hard anti-empty guard. Exit 127 = `agy` not installed; exit 1 = empty after both paths; exit 124 =
  timed out. On any non-zero exit, drop Gemini and note the panel downgraded.

Keep panelists isolated: never paste one panelist's output into another's prompt. The orchestrator (you) is
the judge and must stay separate from the panelists — for `opus4.8-4.8`, both panelists are spawned
subagents, not you, so your synthesis reads all answers fresh.

**Graceful degradation.** If an external panelist exits non-zero, remove it, record a one-line degradation
note (e.g. `gemini dropped: agy empty -> opus4.8-gpt5.5`), and continue with what's left. Order of fallback:
`opus4.8-gpt5.5-gemini3.1pro` → `opus4.8-gpt5.5` → ultimate `opus4.8-4.8` (two independent Opus runs, zero
external CLI). A degraded run still completes; never abort because one CLI failed.

## Step 3 — Judge (adopt the Fable synthesizer prompt)

Read `references/fable_synthesizer.md` and **adopt it as your system prompt for this synthesis pass** —
its style, rigour and formatting discipline govern how you write the analysis and final answer. (Do not
shell out to `claude -p --append-system-prompt`: the judge IS this running session, and a headless call
would burn the Agent-SDK pool instead of staying on the subscription. Adopting the reference in-session is
the faithful realization of "inject the Fable prompt at the judge".)

Then read `references/judge_rubric.md`. Once every panelist has returned, read all responses in full,
attribute claims to each panelist (by model / run), and produce the **five-section analysis**: **Consensus**,
**Contradictions**, **Couverture partielle**, **Insights uniques**, **Angles morts**. Don't average or
smooth over conflict — independent agreement is your highest-confidence signal, and honest disagreement is
the most useful thing the panel produces. A panelist that ran the code or read a primary source outranks one
reasoning from memory, regardless of model. Write this analysis to `/tmp/fusion_analysis.md`.

## Step 4 — Final answer, grounded in the analysis

Write the actual answer to the user's task, grounded in the structured analysis — lead with the
high-confidence consensus, fold in unique insights, flag what stays uncertain. The final answer must follow
*from* the synthesis, not be one panelist's answer lightly edited. Write it to `/tmp/fusion_final.md`.
Answer in French by default (or the user's question language).

## Step 5 — Save provenance + present

Save the run to the internal disk (never `~/Projects` / the 4T) and present:

```bash
FUSION_PANEL_NOTE="<degradation note, or empty>" \
FUSION_ESTIMATE="<the preflight one-liner, optional>" \
bash <skill_dir>/scripts/save_run.sh <SLUG> /tmp/fusion_question.txt /tmp/fusion_analysis.md /tmp/fusion_final.md \
  "opus-A=/tmp/fusion_opusA.md" "gpt5.5=/tmp/fusion_codex_out.md" "gemini=/tmp/fusion_gemini_out.md"
```

Pass one `LABEL=path` per panelist that actually ran (e.g. `opus-A` / `opus-B` for `opus4.8-4.8`). It writes
`~/.claude/fusion-runs/AAAA-MM-JJ_HHMMSS_<slug>.md` and prints the path.

Then, in the chat: lead with the **final answer**, then the structured analysis beneath it as the audit
trail. Name the panel slug you ran and which panelists participated, mention any degradation and how to
enable the fuller panel, and give the saved provenance path.

## Cost & latency note

A panel costs roughly N× a single answer in tokens and runs as slow as its slowest panelist. That's the
deliberate trade: you spend more to stop being confidently wrong where that's expensive. For quick or
low-stakes questions, a single direct answer is the right call — don't reach for Fusion when one model
would obviously do.
