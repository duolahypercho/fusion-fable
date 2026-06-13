# The panel

Fusion's power comes from **independent answers, synthesized** — not from a clever prompt or assigned
personas. You dispatch the same question to several models at once, each works the problem cold with no
knowledge of the others, and a judge fuses their answers. Independent agreement is high-confidence;
independent disagreement is exactly the signal worth surfacing.

## No lenses, no personas

Do not assign panelists "roles" or "stances" (skeptic, optimizer, first-principles, etc.). That biases
*how* each one reasons artificially and corrupts the very independence that makes the panel work. Pass
every panelist the user's task **verbatim** and let each answer it straight.

The diversity is already there for free. Running the same prompt independently produces different
reasoning paths, different tool calls, and different source selections — even when it's the *same model
answering twice*. (Two independent Opus 4.8 runs synthesized by Opus 4.8 beat a single Opus 4.8 run by a
wide margin precisely because of this.) You don't manufacture diversity; you harvest it from independence.

## Independence is the rule

Panelists must never see each other's work. Don't show one panelist another's answer, and don't let the
orchestrator pre-digest or summarize the task before handing it over. The judge is the only place the
answers meet. Cross-pollination before the judge defeats the entire mechanism.

## Panel composition per slug

- `opus4.8-4.8` — the **same prompt run twice** as two independent Opus 4.8 panelists (Agent subagents),
  then judged. Same model, two cold runs.
- `opus4.8-gpt5.5` — Opus 4.8 and GPT-5.5 (codex) answer **in parallel**, then judged.
- `opus4.8-gpt5.5-gemini3.1pro` — Opus 4.8, GPT-5.5, and Gemini 3.1 Pro answer in parallel, then judged.

In every case Opus 4.8 is also the judge/synthesizer, and the judge is kept separate from the panelists
(the panelists are spawned; the orchestrator judges) so the synthesis reads the answers fresh rather than
defending one it wrote itself. Opus always judges and writes the final answer — the pipeline can't be
reversed, since the panelist models can't call back out to spawn Opus.

## Prompt each panelist gets

Each panelist receives the user's task **verbatim**, plus a short instruction: *research with web search
and bash, then return a complete, self-contained answer; you are one of several independent experts and
will not see the others' work.* Nothing more — no lens, no framing that nudges the conclusion.
