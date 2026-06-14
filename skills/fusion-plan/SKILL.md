---
name: fusion-plan
description: >-
  Produce a high-confidence, CONCISE implementation / architecture / strategy PLAN that follows the OMC
  plan system end to end. It first runs OMC's real requirements interview (auto-chains the `omc-plan`
  skill: one question at a time, explore-first, Analyst consult) to produce an initial plan in
  `.omc/plans/`, then DEEPENS that plan with a 3-round ITERATIVE fusion loop — each round an Opus 4.8
  panelist (Agent subagent) and a GPT-5.5 panelist (via codex) critique/improve it IN PARALLEL and BLIND,
  then Opus 4.8 (the orchestrator) judges and synthesizes one tighter plan that seeds the next round,
  stopping early on convergence. Writes the final dense plan back to the same `.omc/plans/<slug>.md`, then
  offers the OMC handoff (`/omc-plan --review` → `/team` or `/ralph`). Use for high-stakes planning,
  architecture decisions, strategy calls, and hard debugging — especially when the user runs /plan or asks
  how to approach a non-trivial build. Reuses the `fusion` skill's run_codex.sh + judge rubric. NOT for
  trivial tasks (single pass is enough).
---

# Fusion-Plan — OMC interview, then a 3-round iterative panel

This skill follows the **OMC plan system**: requirements are gathered by OMC's real interview FIRST, then
the fusion panel deepens the resulting plan, and the output flows back into OMC's review → execution
pipeline. The fusion panel replaces only the *plan-thinking* step; storage, format, the quality gate, and
execution all stay on OMC's rails.

**Hard rule (same as fusion): Opus 4.8 always judges and synthesizes. You are the judge — stay separate
from the panelists.** The Opus panelist is always a *spawned subagent*, never you.

## Step 0 — Requirements (pick the mode FIRST)

**Decide interactive vs non-interactive before doing anything — this determines whether you may interview.**

- **Non-interactive** when ANY of these is true: invoked with `--no-interview`; running autonomously while
  executing a larger plan; running inside a spawned sub-agent; or you otherwise cannot reach a human who
  will answer. **This is the default during plan execution.**
- **Interactive** only when a human is clearly present and able to answer right now — typically the user
  typed `/fusion-plan ...` directly in the main session at the start of a planning session.

### Non-interactive mode (autonomous / sub-agent / `--no-interview`)

**HARD RULE: do NOT interview. Do NOT call `AskUserQuestion`. Do NOT auto-chain the `omc-plan` interview.**
There is no one to answer — blocking on a question would hang the run. Requirements were already gathered
upstream, so derive `SEED_PLAN` from the context that already exists, in this order:

1. The task/story doc if one exists (e.g. `docs/stories/STORY-<id>.md`).
2. The larger plan that flagged this task (e.g. the relevant `.omc/plans/*.md` section).
3. The task description / prompt args you were given.

If that context is genuinely insufficient to plan, do NOT guess and do NOT ask — stop and return a short
note listing exactly what's missing, so the human (or the orchestrator) resolves it. Then go to Step 1.

### Interactive mode (human present)

Run OMC's real requirements interview by invoking the OMC plan skill on the user's request **verbatim**:

```
Skill("oh-my-claudecode:omc-plan")   # pass the user's request; do NOT pass --consensus
```

- Let OMC auto-detect **interview vs direct** mode (one question at a time via `AskUserQuestion`,
  explore-first, Analyst consult). It writes an initial plan to **`.omc/plans/<slug>.md`**.
- Do **NOT** pass `--consensus` (redundant with the fusion panel) and do **NOT** let OMC hand off to
  execution yet — stop at the plan.
- **Capture the plan file path** as `SEED_PLAN` (newest `.omc/plans/*.md` if not reported). It carries the
  gathered requirements — they must survive into the final plan.
- If `omc-plan` is unavailable, fall back to a minimal inline interview (one question at a time).

## Step 1 — Preconditions

This skill targets the `opus4.8-gpt5.5` panel. Check codex is present:

```bash
command -v codex && codex --version
```

- If `codex` is installed → run the full Opus 4.8 + GPT-5.5 loop below.
- If `codex` is **missing** → tell the user, then fall back to two independent Opus 4.8 panelists per round
  (`opus4.8-4.8`) rather than failing. Note the downgrade and how to enable GPT-5.5 (`npm i -g
  @openai/codex` + `codex login`).

Read the shared references once (they live in the sibling skill):

```bash
cat ~/.claude/skills/fusion/references/panel.md
cat ~/.claude/skills/fusion/references/judge_rubric.md
```

Honor `panel.md`: every panelist gets the same input **verbatim**, no assigned "lenses" or personas.

## Step 2 — The loop, SEEDED from the OMC plan (round R = 1, 2, 3)

The panel does NOT draft blind — round 1 is already seeded by `SEED_PLAN`, so the interview's requirements
anchor everything.

### 2a. Build each panelist's prompt

- **Every round (1, 2, 3) — independent critique-and-improve:** the original request **verbatim**, plus
  the current plan, plus:
  > Here is the current plan (round 1: the requirements + initial plan from a stakeholder interview;
  > later rounds: the synthesized plan from the previous round):
  > ```
  > <round 1: SEED_PLAN | round R>1: PLAN v(R-1)>
  > ```
  > You are one of several independent expert planners; you will not see the others' work. Research with
  > web + bash as needed, then return an IMPROVED, COMPLETE plan. **Preserve every requirement and
  > constraint already captured** — do not drop them. Fix wrong assumptions, fill gaps, add missing
  > risks/edge cases, sharpen sequencing and decisions, and CUT padding — the plan must get tighter and
  > denser, not longer. If you genuinely believe no material improvement is possible, say so explicitly on
  > the first line (`NO_MATERIAL_CHANGE`) and return the plan unchanged.

Within a round, keep panelists **isolated** — never paste one panelist's round-R output into the other's
round-R prompt. The only shared input across a round is the previous round's synthesized plan (or
`SEED_PLAN` in round 1).

### 2b. Launch BOTH panelists in ONE turn (parallel, blind)

- **Opus 4.8 panelist** → `Agent` tool, `subagent_type: general-purpose`, `model: opus`, prompt = the
  panelist prompt above. Spawn a **fresh** subagent each round. **Prefix the Agent prompt's first line with
  the literal marker `[FUSION-PANELIST]`** so spawn hooks recognize and skip fusion's own panelist spawns
  (otherwise the plan-nudge backstop would fire on them).
- **GPT-5.5 panelist** → write the prompt to a temp file and run codex at **high** effort:
  ```bash
  printf '%s' "$PROMPT" > /tmp/fusion_plan_codex_r${R}_prompt.txt
  bash ~/.claude/skills/fusion/scripts/run_codex.sh \
    /tmp/fusion_plan_codex_r${R}_prompt.txt /tmp/fusion_plan_codex_r${R}_out.md high
  ```
  Read the out file once it finishes. Exit 127 / missing-codex → apply the Step 1 fallback.

Send the Agent call and the codex Bash call in the **same message** so they run concurrently.

### 2c. Judge → synthesize Plan vR

When both panelists return, follow `judge_rubric.md` **Track B**: build the structured analysis over the
two plans — **Consensus · Contradictions · Partial coverage · Unique insights · Blind spots** — then write
**Plan vR**: the single best plan grounded in it. Do not average or smooth over conflict; independent
agreement is your highest-confidence signal. A panelist that failed or was dropped is treated as
**absent**, never as silent agreement. **Every requirement from `SEED_PLAN` must still be present** in the
synthesis — if a panelist dropped one, restore it.

### 2d. Early stop

If `R >= 2` and **both** panelists returned `NO_MATERIAL_CHANGE`, the plan has converged: finalize and skip
the remaining round(s). Record the convergence round.

## Step 3 — Write the CONCISE final plan back to `.omc/plans/`

The deliverable is **short but content-dense** — every line load-bearing, no filler, no restating the
task, no hedging. A round that only added length without adding/correcting a decision did NOT improve the
plan. Aim for the tightest plan a competent implementer could execute from without follow-up questions.

Write it back to the **same `SEED_PLAN` file** (`.omc/plans/<slug>.md`) so there is ONE OMC artifact,
in the OMC standard format:

- **Requirements Summary** — 2–4 lines (must reflect what the interview established).
- **Acceptance Criteria** — testable, concrete (90%+ measurable; no vague terms — "fast" → "p99 < 200ms").
- **Implementation Steps** — ordered; each names the file(s)/component(s) it touches (cite `file:line` for
  existing code — aim 80%+ of existing-code claims cite a path).
- **Risks & Mitigations** — only real ones, each with a mitigation.
- **Verification** — how each step is proven end-to-end. In the KHON repo, map to the proof-ladder (L0–L4)
  and "mutation needs readback / cross-service needs same-run proof".
- **ADR** (compact) — Decision · Drivers · Alternatives rejected (+ why) · Consequences. A few lines each.
- **Sub-task flags (only if the plan decomposes into multiple sub-tasks/stories):** mark each NON-TRIVIAL
  sub-task inline with `⟡ DEEP-PLAN: /fusion-plan --no-interview before implementing`. This is how
  autonomous execution knows where to trigger a per-task panel (requirements will come from this plan +
  any story doc, non-interactively). Leave trivial sub-tasks unflagged — don't flag everything.

Keep ceremony minimal: add a pre-mortem / expanded test matrix ONLY if the task is genuinely high-risk
(auth/security, migration, destructive/irreversible, production incident, PII). Otherwise the six sections
above are enough — do not pad to look thorough.

## Step 4 — Present, then hand off to the OMC pipeline

Present in chat:

1. **Final Plan** — the dense plan inline (or a tight summary + the `.omc/plans/<slug>.md` path if long).
2. **Convergence trail** — 1–2 lines per round: interview seed → v1 → v2 → v3, what each round changed
   (decisions added / removed / corrected). Evidence the iteration earned its tokens.
3. **Panel line** — panel slug (`opus4.8-gpt5.5`), rounds run, early-stop or not, any downgrade.

Then **offer** the OMC handoff — do not auto-run execution without the user's go-ahead:

- **Quality gate (recommended first):** OMC plan *review* mode on the file —
  `Skill("oh-my-claudecode:omc-plan")` with `--review .omc/plans/<slug>.md` (or `/omc-plan --review
  .omc/plans/<slug>.md`). Returns APPROVED / REVISE / REJECT against OMC's standards **without bloating the
  plan**. On REVISE, fold feedback in and keep it tight.
- **Execute:** on APPROVED, hand the plan path to `/team` (default) or `/ralph`.

This split is deliberate and follows the OMC plan system: **OMC owns the interview, storage format,
quality gate, execution handoff, and ralplan state lifecycle; fusion-plan only replaces the plan-thinking
step with a blind 2-model 3-round panel.** Do NOT edit OMC's own skills (overwritten on `omc update`) —
integrate only through the shared `.omc/plans/*.md` artifact and by invoking the `omc-plan` skill.

## Cost & latency note

One run is the OMC interview + ~6 panelist runs + 3 judge passes — several× a single plan, as slow as the
slowest panelist per round, plus interactive interview time up front. That is the deliberate trade for
high-stakes planning where a wrong plan is expensive. For trivial or low-stakes planning, run plain
`/omc-plan` (or `/fusion-gpt5.5`) instead — don't reach for the full chain when one would obviously do.
