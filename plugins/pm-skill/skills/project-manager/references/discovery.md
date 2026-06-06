# Discovery

Understand what the customer actually needs and agree the best solution — before specification and
planning.

## Goal
Reach a shared, explicit understanding with the user (the customer-facing manager) of:
- the problem and who has it,
- what success looks like,
- the solution direction you both believe is best.

## How to run it
- Talk *with* the user; build on their answers. Ask **one question at a time** — don't interrogate.
- When a decision has real options, present **2–3** with trade-offs and your recommendation, and
  say why.
- Cover: purpose and value, must-haves vs nice-to-haves, constraints (tech, time, audience), and
  how you'll know it worked.
- When something is unknown or ambiguous, **write it down inline as `[NEEDS CLARIFICATION: …]`**
  instead of guessing. Ambiguity carried into planning is the most common cause of a wrong build.

## Protect your context
- You are the PM. Keep the conversation and the decisions in this thread.
- For anything that needs heavy reading (existing code, docs, prior art), dispatch the built-in
  `general-purpose` (or `Explore`) subagent with a tight question and have it return a short
  summary. Don't read large sources into your own context.

## Exit gate
Move on once you and the user share the problem and the solution direction. You needn't resolve every
detail here — record open unknowns inline as `[NEEDS CLARIFICATION: …]`; the **specification** phase
captures them and `/pm-skill:clarify` resolves them before planning. Settle now only anything that
would block even writing a spec.

## Output
- A short, shared **problem statement** and the chosen **solution direction**.
- Append a one-line entry to `tmp/log.md` (create it if missing) noting discovery is done and the
  direction agreed.

Then load `specification.md`.
