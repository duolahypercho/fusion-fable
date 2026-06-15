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
task. (Answer in the user's question language.)

Launch **all panelists in a single turn** so they run concurrently:

- **Opus 4.8 panelist(s)** → the `Agent` tool, `subagent_type: general-purpose` (web + bash built in).
  For `opus4.8-4.8`, spawn **two** independent Opus subagents with the *same* prompt — two cold runs.
  Spawn them in the same message so they run at once. When each returns, write its answer to a temp file
  for provenance: `/tmp/fusion_opusA.md` (and `/tmp/fusion_opusB.md` for the second Opus run).
- **GPT-5.5 panelist** (if slug includes it) → write its prompt to a temp file, then run:
  ```bash
  fusion_run_dir="$(mktemp -d "${TMPDIR:-/tmp}/fusion-panel.XXXXXX")"
  bash <skill_dir>/scripts/run_codex.sh "$fusion_run_dir/codex_prompt.md" "$fusion_run_dir/codex_out.md" xhigh
  ```
  Allocate one unique `fusion_run_dir` per Fusion invocation and put every prompt/output file for that
  invocation under it. Never use fixed paths like `/tmp/fusion_codex_prompt.txt` or
  `/tmp/fusion_codex_out.md`; multiple Claude Code sessions can run Fusion concurrently, and fixed names
  let one run read another run's prompt or answer.
  The runner copies the current repo/workdir to a throwaway directory, then launches `codex exec` with
  full local access against that copy. This preserves the live checkout while letting the GPT-5.5 panelist
  use the same local tools and keychain-backed credentials as a trusted terminal Codex run. `-o` makes
  codex write only its final answer to the out file; read it once it finishes. Exit 124 = timed out
  (`FUSION_TIMEOUT`); any other non-zero exit = drop GPT-5.5 and note the panel downgraded.
- **Gemini panelist** (if slug includes it) →
  ```bash
  bash <skill_dir>/scripts/run_gemini.sh "$fusion_run_dir/gemini_prompt.md" "$fusion_run_dir/gemini_out.md"
  ```
  This calls `agy` under a pseudo-TTY (working around agy bug #76, which emits empty stdout with no TTY)
  with a transcript-JSONL fallback and a hard anti-empty guard, so it never returns a silently empty
  answer. Exit 127 = `agy` not installed; exit 1 = empty after both paths; exit 124 = timed out. On any
  non-zero exit, drop Gemini and note the panel downgraded.

Keep panelists isolated: never paste one panelist's output into another's prompt. The orchestrator (you) is
the judge and must stay separate from the panelists — for `opus4.8-4.8`, both panelists are spawned
subagents, not you, so your synthesis reads all answers fresh.

**Graceful degradation.** If an external panelist exits non-zero, remove it, record a one-line degradation
note (e.g. `gemini dropped: agy empty -> opus4.8-gpt5.5`), and continue with what's left. Order of fallback:
`opus4.8-gpt5.5-gemini3.1pro` → `opus4.8-gpt5.5` → ultimate `opus4.8-4.8` (two independent Opus runs, zero
external CLI). A degraded run still completes; never abort because one CLI failed.

## Step 3 — Judge (pick the track that fits the task)

Once every panelist has returned, read `references/judge_rubric.md` and **classify the deliverable first**,
because code and prose merge completely differently:

- **Artifact task** (code, script, config, Minecraft mod/datapack, schema — the user wants a buildable
  thing) → **Track A: run both, then merge**. You are integrating two *implementations* into one working
  program, not writing a report. **Run each candidate with bash first** to see what actually works and what
  breaks in each, decide what to keep based on observed behavior (not on which looks better), graft the
  parts that worked onto the stronger base, then **run the merged result and fix until it passes**. The
  panel's value here is that two independent attempts expose each other's bugs — running both is how you
  find which one is actually right, so the merge ends up **more correct than either input**. (If it truly
  can't be executed here — needs the live game or an unavailable toolchain — fall back to seam-reasoning
  and mark it unverified.)
- **Research / analysis task** (the user wants understanding or a recommendation) → **Track B: structured
  synthesis** — the five sections: **Consensus**, **Contradictions**, **Partial coverage**, **Unique
  insights**, **Blind spots**. Don't average or smooth over conflict; independent agreement is your
  highest-confidence signal, honest disagreement is the most useful thing the panel produces. Write this
  analysis to `/tmp/fusion_analysis.md` for the provenance record.

Either way: attribute decisions to each panelist (by model / run), and weight a panelist that actually ran
the code or read a primary source over one reasoning from memory. If a panelist failed or was dropped, the
judge treats it as **absent** — never as silent agreement.

## Step 4 — Final deliverable

- **Track A (code/artifact):** emit the complete, merged artifact — every file, ready to run as-is, not a
  diff or "take A's X and B's Y." Per `judge_rubric.md`, you got here by **running both candidates** and
  keeping what worked, and you **run the merged result and fix it until it passes** before presenting.
  Follow with a tight merge rationale: what each candidate did when run, what you took from each, and what
  you verified.
- **Track B (research):** write the answer grounded in the structured analysis — lead with high-confidence
  consensus, fold in unique insights, flag what stays uncertain. It must follow *from* the synthesis, not
  be one panelist's answer lightly edited. Write it to `/tmp/fusion_final.md` for the provenance record.

## Step 5 — Save provenance

Save the run to an internal provenance file under `~/.claude/fusion-runs/` (raw panelist answers + the
analysis + the final answer, timestamped, for auditing):

```bash
FUSION_PANEL_NOTE="<degradation note, or empty>" \
FUSION_ESTIMATE="<the preflight one-liner, optional>" \
bash <skill_dir>/scripts/save_run.sh <SLUG> /tmp/fusion_question.txt /tmp/fusion_analysis.md /tmp/fusion_final.md \
  "opus-A=/tmp/fusion_opusA.md" "gpt5.5=$fusion_run_dir/codex_out.md" "gemini=$fusion_run_dir/gemini_out.md"
```

(`save_run.sh` substitutes a placeholder for any answer file that is missing or empty, so a degraded panel
still produces a complete record.)

## Step 6 — Present

Lead with the **final deliverable** — the merged working artifact (Track A) or the grounded answer
(Track B) — then the audit trail beneath it: for code, what each candidate did when run + the
merge rationale + what you verified; for research, the five-section analysis. Name the panel slug you ran and which panelists participated. If the
panel downgraded because a CLI was missing, say so and how to enable the fuller panel (install the missing
CLI).

## Cost & latency note

A panel costs roughly N× a single answer in tokens and runs as slow as its slowest panelist. That's the
deliberate trade: you spend more to stop being confidently wrong where that's expensive. For quick or
low-stakes questions, a single direct answer is the right call — don't reach for Fusion when one model
would obviously do.
