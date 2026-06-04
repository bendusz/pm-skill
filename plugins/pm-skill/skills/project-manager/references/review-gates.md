# Review Gates

How a story is judged done. Two independent checks: a **reviewer agent** (qualitative) and
**deterministic gates** (mechanical). They are separate on purpose.

## The reviewer (separate agent)
- `code-integrity-reviewer` is **never** the agent that built the story (this avoids self-review
  blind spots) and is read-only.
- Findings are graded: **`block`** (must fix), **`major`** (must fix), **`minor`** (note, optional).
- Each review ends with a verdict: **`PASS`** (no block/major), **`CONCERNS`** (only minor), or
  **`FAIL`** (one or more block/major).
- Only `block`/`major` force a fix round.

## The review panel — select lenses by risk
Reviewers are separate agents, each a distinct lens. Run only the lenses a story warrants:
- **Always:** `code-integrity-reviewer` (correctness + security baseline).
- **Add `architecture-reviewer`** when the story changes structure — new modules, refactors,
  cross-cutting changes, or new abstractions/interfaces. **Skip** it for trivial, localized changes.
- **Add `security-auditor`** — a deeper security lens than the baseline — when the story touches
  auth/authz, crypto, secrets/credentials, external or untrusted input, file/network/process I/O,
  deserialization, or dependency changes. **Skip** it for changes with no security surface.
- *(Extensible: a performance lens for hot paths can join when such an agent is available.)*
A reviewer is never the agent that built the story. Aggregate the verdicts: the story passes review
only when **every selected lens** has no open `block`/`major`. Before acting, **triage** the
findings — dedupe across lenses and drop false positives / out-of-scope items — and fix only the
real `block`/`major` ones.

`technical-writer` and `debugger` are *delivery* agents, not review lenses — they never gate a story.

## Deterministic gates (you run these)
- The gates are the project's **actual** `test` / `lint` / `build` commands as recorded in the plan
  and `CLAUDE.md`. Any that don't exist are `N/A` and skipped.
- **You** (the PM) run them — after the build, and again after each fix. Don't take a subagent's
  word that they pass.

## Definition of done (a story)
A story is done when **all** of these hold:
- every acceptance criterion is met,
- no open `block`/`major` findings across **all** selected review lenses,
- all non-`N/A` gates are green,
- the outcome is logged.

## Escalation
If a story isn't done after **3** fix/verify iterations, **stop and ask the user** — don't loop
forever.
