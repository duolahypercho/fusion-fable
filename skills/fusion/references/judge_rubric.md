# Judge rubric

The judge is Opus 4.8 — the orchestrator, reading every panelist's response *after* all of them have
returned independently. The judge does not vote or average. It extracts the structure of the panel's
collective reasoning, then writes the final answer **grounded in that structure**. A good judge pass makes
agreement and disagreement legible rather than blending them into mush.

Read every panelist response in full first. Attribute claims to specific panelists by model (e.g. "Opus
run A", "Opus run B", "GPT-5.5", "Gemini") so the user can trace any point back to its source.

## Stage 1 — Structured analysis

Produce these five sections from the independent answers:

### Consensus
Points where panelists independently agree. Independent agreement — especially across different model
families, but also across two cold runs of the same model — is the strongest signal in the panel; flag it
as high-confidence. Note how many converged and whether any reached it by a different route.

### Contradictions
Direct disagreements on fact or recommendation. For each, state the competing positions, who holds them,
and — where you can — adjudicate: which side ran the code, read the primary source, or has better
evidence? If you can't resolve it, say so and name what evidence would settle it. Never bury a real
conflict to look tidy.

### Partial coverage
Important sub-questions only some panelists engaged. Surfaces depth a single answer would have missed.

### Unique insights
Non-obvious, valuable points raised by exactly one panelist that the others didn't reach. These are often
the highest-leverage payoff of fanning out — preserve them even if they don't fit the majority view.

### Blind spots
What the panel *as a whole* missed, under-weighted, or got wrong — including failure modes none tested and
assumptions all of them shared. As judge you're positioned to catch what every panelist shared; you may
add a blind spot none of them named.

## Stage 2 — Final answer, grounded in the analysis

Now write the actual answer to the user's task, grounded in stage 1. Lead with what's high-confidence
(consensus + adjudicated contradictions), fold in the unique insights where they improve the answer, and
flag what remains genuinely uncertain. This is the deliverable; the analysis above is the audit trail that
justifies it. The final answer must follow *from* the synthesis — not be one panelist's answer lightly
edited.

## Principles

- Faithfully report disagreement — a panel that "all agreed" when it didn't is worse than useless.
- Weight evidence over assertion: a panelist that ran the code or read the primary source outranks one
  reasoning from memory, regardless of which model it is.
- Stay honest about confidence. If the whole panel was guessing, the final answer says so.
- Keep attribution throughout so the user can audit any claim back to its source panelist.
