# Model Tiering

Control cost/quality by giving heavier work a stronger model and routine work a cheaper one.

## Shipped defaults (v0.9.2)
Every agent ships pinned to an explicit model **and** reasoning-effort level, so the workflow's
behaviour is reproducible regardless of which model the session happens to run:

| Agent | Model | Effort | Why |
| --- | --- | --- | --- |
| `expert-builder` | `fable` | `medium` | writes the code — the one role on the top-tier model |
| `security-auditor` | `opus` | `high` | adversarial security reasoning rewards extra thinking depth |
| `debugger` | `opus` | `high` | root-cause analysis is the workflow's hardest read-only task |
| `code-integrity-reviewer` | `opus` | `medium` | judgement-heavy review at standard depth |
| `architecture-reviewer` | `opus` | `medium` | design judgement at standard depth |
| `pm-verifier` | `opus` | `medium` | independent evidence-checking at standard depth |
| `test-engineer` | `opus` | `medium` | derives tests from written criteria |
| `codebase-analyst` | `opus` | `medium` | reads and summarises; breadth over depth |
| `technical-writer` | `opus` | `medium` | documents already-shipped facts |

Pinned agents do **not** follow the session model — changing the session tier changes only the PM
itself, not the specialists.

## Overriding
- **Per agent, model:** edit the `model:` field in the agent's frontmatter — any Claude Code model
  alias (`haiku`/`sonnet`/`opus`/`fable`) or full model ID, or `inherit` to follow the session.
  (Plugin updates overwrite edited bundled agents — keep a note of your overrides.)
- **Per agent, effort:** edit the `effort:` field — `low`, `medium`, `high`, `xhigh`, or `max`
  (available levels depend on the model); remove the field to inherit the session's effort level.
- **Cheaper everywhere:** pin agents down a tier (e.g. reviewers to `sonnet`) and/or lower their
  effort. Scaling down never relaxes the workflow's gates — a cheap reviewer still needs its
  verdict, and `pm-verifier` PASS is still required to ship.

## Guidance, not automation
The PM never silently switches models mid-project. If you change the mapping, record it in the
project `CLAUDE.md` so it's visible and reproducible.
