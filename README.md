# Fusion-Fable

**Fuse a panel of frontier models into one Fable-tier answer.**

Fusion-Fable is a [Claude Code](https://claude.com/claude-code) skill that runs a hard question through a
**panel → judge** pipeline. The same prompt is dispatched to several models *in parallel* — each answering
independently with web search and bash, none seeing the others' work — and then Opus 4.8 judges every
answer into a structured analysis (consensus, contradictions, partial coverage, unique insights, blind
spots) and writes a final answer grounded in it.

The mechanism is **independence, then synthesis**. The diversity that makes a panel beat a single model is
harvested, not manufactured: running the same prompt independently yields different reasoning paths, tool
calls, and sources — even two cold runs of the *same* model diverge enough that synthesizing them beats
running it once. So there are no contrived "lenses" or personas; every panelist gets the task verbatim and
answers it straight. Fuse **Opus 4.8 + Opus 4.8**, or **Opus 4.8 + GPT-5.5** (via the `codex` CLI), into a
result better than either alone — a Fable-tier fusion.

```
                      ┌──────────────┐
                 ┌──▶ │  panelist 1  │ ─┐   (web + bash, independent)
                 │    └──────────────┘  │
                 │    ┌──────────────┐  │   ┌──────────────┐
 prompt ──▶ fan ─┼──▶ │  panelist 2  │ ─┼─▶ │   Opus 4.8   │ ──▶ final answer
            out  │    └──────────────┘  │   │   (judge +   │     (grounded in
                 │    ┌──────────────┐  │   │  synthesize) │      the analysis)
                 └──▶ │  panelist 3  │ ─┘   └──────────────┘
                      └──────────────┘
              Opus 4.8 / GPT-5.5 / Gemini      consensus · contradictions ·
              (each answers blind)             partial · unique · blind spots
```

Opus 4.8 **always** judges and writes the final answer — the pipeline can't be reversed, because the
panelist models can't call back out to spawn Opus.

## The panels

| Slug | Panel | Requires |
| --- | --- | --- |
| `opus4.8-4.8` | the **same prompt run twice** as 2 independent Opus 4.8 panelists → Opus judges | nothing — works everywhere |
| `opus4.8-gpt5.5` | Opus 4.8 + **GPT-5.5** (codex) in parallel → Opus judges | the `codex` CLI |
| `opus4.8-gpt5.5-gemini3.1pro` | Opus 4.8 + GPT-5.5 + **Gemini 3.1 Pro** in parallel → Opus judges | `codex` + `agy` CLIs |

The skill auto-detects which panelist CLIs are installed and uses the richest panel available, falling
back gracefully when one is missing.

## Install

```bash
git clone https://github.com/duolahypercho/fusion-fable.git
cd fusion-fable
./install.sh
```

This copies the skill to `~/.claude/skills/fusion` and the slash commands to `~/.claude/commands`,
then prints which panels your machine can run. Restart Claude Code (or run `/reload-skills`) afterward.

> Override the target with `CLAUDE_CONFIG_DIR=/path/to/.claude ./install.sh`.

## Use it

Three ways, all equivalent under the hood:

- **Natural language** — just ask. The skill auto-triggers and picks the richest panel:
  > "Run this through Fusion: is it safe to `ALTER TABLE … ADD COLUMN` on a 200M-row Postgres table in prod?"
- **Pinned slash commands:**
  ```
  /fusion-opus4.8  does my JWT refresh-rotation design have a replay hole?
  /fusion-gpt5.5   is git push --force-with-lease actually safe on a shared branch?
  /fusion-3        full 3-family panel (Opus 4.8 + GPT-5.5 + Gemini 3.1 Pro)
  ```
- **Force a panel in prose** — "run the `opus4.8-gpt5.5` Fusion on …".

Every run returns the same structure: a **Final answer** up top, then the audit trail —
**Consensus / Contradictions / Partial coverage / Unique insights / Blind spots** — with each point
attributed to the panelist that raised it, so you can see how the answer was assembled. Every run is also
written to a timestamped provenance file under `~/.claude/fusion-runs/` (raw panelist answers + analysis +
final answer) for auditing.

## Requirements

- **Claude Code**, with the session running **Opus 4.8** (panelist subagents and the judge inherit the
  session model — on another model the slug is nominal, not literal).
- For `opus4.8-gpt5.5`: the [`codex` CLI](https://github.com/openai/codex) installed and logged in to an
  account with GPT-5.5 access. The runner uses `codex exec` (tested against `codex-cli` 0.139).
  It runs against a throwaway copy of the current repo/workdir with trusted local access so tools such as
  `gh`, local test runners, Docker, and SDK-managed toolchains behave like they do in your terminal without
  writing back to the live checkout.
  Each Fusion invocation uses its own temporary prompt/output directory, so concurrent runs in different
  Claude Code sessions do not read each other's GPT panelist artifacts.
- For the 3-model panel: the **`agy`** (Antigravity) CLI installed and its keyring seeded — run `agy` once
  interactively to complete the Google OAuth, after which headless runs reuse that login. `run_gemini.sh`
  works around agy's print-mode bug (empty stdout under no TTY) by running it under a pseudo-TTY with a
  transcript-JSONL fallback and a hard anti-empty guard, so it never returns a silently empty answer. The
  pseudo-TTY is allocated by a `pty.fork()` Python helper (`_pty_run.py`) so it keeps working when the
  orchestrator itself runs in a socket (cmux / headless), where `script` aborts on `tcgetattr`.

Only the **`opus4.8-4.8`** panel is truly zero-setup; the GPT-5.5 and Gemini panels light up once their
CLIs are installed and authenticated. Note: there is no `timeout`/`gtimeout` on stock macOS, so the runners
use a self-contained `perl` timeout helper (`FUSION_TIMEOUT`, default 300s per panelist).

## What's in here

```
skills/fusion/
  SKILL.md                  detect → preflight → blind fan-out → judge → grounded final → save
  scripts/
    _fusion_lib.sh          shared helpers: perl-based per-panelist timeout, have()
    _pty_run.py             pty.fork() runner so agy gets a TTY even under socket stdio (cmux/headless)
    detect_panel.sh         picks the richest available panel
    preflight.sh            non-blocking token/call estimate + Codex cap reminder
    run_codex.sh            runs the GPT-5.5 panelist (web + bash) with a timeout, captures its answer
    run_gemini.sh           runs the Gemini 3.1 Pro panelist via agy (pseudo-TTY + transcript fallback)
    save_run.sh             writes the timestamped provenance .md to ~/.claude/fusion-runs/
  references/
    panel.md                why independent parallel runs (no lenses) — the panel mechanism
    judge_rubric.md         the structured analysis + grounded final answer
commands/
  fusion-opus4.8.md         /fusion-opus4.8  (pinned opus4.8-4.8 panel)
  fusion-gpt5.5.md          /fusion-gpt5.5   (pinned opus4.8-gpt5.5 panel)
  fusion-3.md               /fusion-3        (pinned full opus4.8-gpt5.5-gemini3.1pro panel)
install.sh                  copies the above into ~/.claude
```

## Why a panel beats one model

On the DRACO deep-research benchmark, OpenRouter found that fusing model answers consistently beats the
individual models — and that a meaningful chunk of the lift comes from the *synthesis step itself*, not
just from mixing architectures: two independent runs of one model, synthesized, beat that model run once.
Fusion-Fable implements that same independence-then-judge pipeline locally in Claude Code.

## Cost & latency

A panel costs roughly N× a single answer in tokens and runs as slow as its slowest panelist. That's the
deliberate trade: spend more to stop being confidently wrong where that's expensive. For quick or
low-stakes questions, a single direct answer is the right call.

## License

MIT — see [LICENSE](LICENSE).
