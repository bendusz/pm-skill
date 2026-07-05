# Model Tiering

Control cost/quality by giving heavier work a stronger model and routine work a cheaper one.

## Shipped defaults (v0.9.1)
Four routine agents ship pinned to Claude Code's mid-tier alias — the community-standard mapping
for these roles (debugging, test authoring, docs, codebase analysis):

| Agent | Shipped model | Why |
| --- | --- | --- |
| `debugger` | `sonnet` | procedural evidence-tracing; checklist-shaped work |
| `test-engineer` | `sonnet` | derives tests from written criteria |
| `technical-writer` | `sonnet` | documents already-shipped facts |
| `codebase-analyst` | `sonnet` | reads and summarises; volume over depth |

The five quality-critical agents — `expert-builder`, `code-integrity-reviewer`,
`architecture-reviewer`, `security-auditor`, `pm-verifier` — ship as `model: inherit`: they follow
whatever model the session runs, so the judgement-heavy work always gets the model you chose.

## Overriding
- **Per agent:** edit the `model:` field in the agent's frontmatter — any Claude Code model alias
  (`haiku`/`sonnet`/`opus`/…) or full model ID, or `inherit`. (Plugin updates overwrite edited
  bundled agents — keep a note of your overrides.)
- **Stronger everywhere:** run the session on a stronger model; the `inherit` agents follow it.
  To force the pinned four up a tier as well, change their frontmatter.
- **Cheaper everywhere:** run the session on a cheaper model and/or pin more agents down a tier.
  Scaling models down never relaxes the workflow's gates — a cheap reviewer still needs its
  verdict, and `pm-verifier` PASS is still required to ship.

## Guidance, not automation
The PM never silently switches models mid-project. If you change the mapping, record it in the
project `CLAUDE.md` so it's visible and reproducible.
