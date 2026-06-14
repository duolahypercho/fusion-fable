---
description: OMC interview (interactive) → 3-round Opus 4.8 + GPT-5.5 fusion deepening → concise .omc/plans/ output → review/execute handoff
argument-hint: "[--no-interview] <what to plan / decide>"
---
Invoke the **fusion-plan** skill on the task below. Run the full OMC-integrated flow:

1. **Requirements — pick the mode FIRST (Step 0 of SKILL.md):**
   - **Non-interactive** (default during plan execution, inside a sub-agent, or `--no-interview`): **do NOT
     interview, do NOT call AskUserQuestion, do NOT auto-chain omc-plan.** Derive requirements from existing
     context (story doc `docs/stories/STORY-*.md`, the flagged section of the larger `.omc/plans/*.md`, and
     the task args) as the seed. If context is insufficient, stop and report what's missing — never block on
     an unanswerable question.
   - **Interactive** (a human is present, typed `/fusion-plan` directly): run OMC's real interview via
     `Skill("oh-my-claudecode:omc-plan")` on the task verbatim (no `--consensus`; auto-detect interview vs
     direct) → initial plan in `.omc/plans/<slug>.md`. Capture that path as the seed; do not let OMC
     auto-execute.
2. **Deepen with the panel (3 rounds, seeded):** each round, ONE Opus 4.8 panelist (Agent subagent,
   `model: opus`) and ONE GPT-5.5 panelist (`codex exec`, **high** effort) independently critique-and-improve
   the current plan IN PARALLEL and BLIND. Round 1 seeds from the OMC plan (so every interview requirement
   is preserved); rounds 2–3 seed from the previous synthesis. After each round YOU (Opus 4.8) judge both
   (Consensus / Contradictions / Partial / Unique / Blind spots) and synthesize one tighter plan. Stop early
   on `NO_MATERIAL_CHANGE` (round ≥ 2). If `codex` is missing, fall back to two Opus 4.8 panelists per round.
3. **Write back:** the synthesized plan must be **concise but content-dense** (no padding) and is written
   back to the SAME `.omc/plans/<slug>.md` in OMC standard format, preserving all gathered requirements.
4. **Handoff (offer, don't auto-run execution):** quality gate via `/omc-plan --review .omc/plans/<slug>.md`,
   then `/team` or `/ralph` on approval.

Follow `skills/fusion-plan/SKILL.md` exactly. Do not edit OMC's own skills — integrate only through the
`.omc/plans/*.md` artifact and by invoking `omc-plan`.

Task: $ARGUMENTS
