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
- *(Extensible: a `security-auditor` lens for auth/crypto/external-input/secret/dependency stories,
  and a performance lens for hot paths, join when those agents are available.)*
A reviewer is never the agent that built the story. Aggregate the verdicts: the story passes review
only when **every selected lens** has no open `block`/`major`.

## Deterministic gates (you run these)
- The gates are the project's **actual** `test` / `lint` / `build` commands as recorded in the plan
  and `CLAUDE.md`. Any that don't exist are `N/A` and skipped.
- **You** (the PM) run them — after the build, and again after each fix. Don't take a subagent's
  word that they pass.

## Definition of done (a story)
A story is done when **all** of these hold:
- every acceptance criterion is met,
- no open `block`/`major` findings,
- all non-`N/A` gates are green,
- the outcome is logged.

## Escalation
If a story isn't done after **3** fix/verify iterations, **stop and ask the user** — don't loop
forever.
