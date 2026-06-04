# Model Tiering (optional)

A way to control cost/quality by giving heavier work a stronger model and routine work a cheaper one.
**Entirely optional.** Every bundled agent ships as `model: inherit`, so out of the box the plugin
makes no model choices for you — it uses whatever model the session runs. Adopt this only if you want
to.

## Abstract tiers (map these to your own models)
This plugin names tiers, not models — so it stays generic and never hardcodes a vendor's model IDs.
Map each tier to a model you have access to.

| Tier | Use for | Why |
| --- | --- | --- |
| **deep** | planning, architecture review, security audit, debugging root-cause | judgement-heavy, low-volume, high cost-of-error |
| **standard** | building stories, code-integrity review, writing tests | the bulk of delivery work |
| **light** | logging, formatting, doc boilerplate, simple summaries | high-volume, low-risk |

Roughly: `codebase-analyst`, `architecture-reviewer`, `security-auditor`, `debugger` → **deep**;
`expert-builder`, `code-integrity-reviewer`, `test-engineer` → **standard**; routine text →
**light**. Treat this as a starting point, not a rule — tune per project.

## How to opt in
- **Per agent:** set the `model:` field in an agent's frontmatter to your chosen model instead of
  `inherit`. (If you change a bundled agent, keep a note — an update could overwrite it.)
- **Per session:** run the whole session on the model you want; `inherit` agents follow it.
- Check your Claude Code version's docs for the exact per-agent model syntax and the available model
  names — they change over time, so this guide deliberately doesn't pin them.

## Guidance, not automation
The PM never silently switches models. If you adopt tiers, decide the mapping up front and record it
in the project `CLAUDE.md` so it's visible and reproducible. Leaving everything on `inherit` is a
perfectly good default.
