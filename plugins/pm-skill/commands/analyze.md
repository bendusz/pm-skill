---
description: Read-only consistency and quality analysis across the PM artifacts (spec, plan, stories, constitution, state). Never edits.
---

Use the `project-manager` skill to run a **read-only** cross-artifact analysis. Load
`references/artifact-consistency.md` and follow it.

Scope: $ARGUMENTS  (optional — narrow to a sprint, story, or requirement; default is everything)

Inputs (whichever exist): `docs/constitution.md`, `docs/spec.md`, `docs/plan.md`,
`docs/stories/*.md`, `pm/pm-state.json`, `pm/actors/*.json`, `pm/log.md`. Note any that are
absent. Team checks: a **claim conflict** — an actor file whose `current_story` names a story that
`assignments` maps to a *different* actor, or two actor files sharing one **non-null**
`current_story` (idle/new actors all carry `current_story: null` — never flag those)
(`assignments` is a story→actor map, so it can only ever show one claimant — the race surfaces in
the actor files; compare them against the map); an assignment pointing at a nonexistent story or
actor file; in-flight stories of **different actors** whose `Touches` overlap (serialize or
re-scope them).

**Strictly read-only.** Do **not** edit, create, fix, or scaffold anything — not even logs or state.
You may *suggest* remediation; you must not apply it.

Produce the report defined in `references/artifact-consistency.md`: a findings table with severities
**CRITICAL / HIGH / MEDIUM / LOW**, a coverage summary, unmapped stories, constitution alignment, and
next actions. End by stating the headline status (e.g. "2 CRITICAL, 3 HIGH") and recommending whether
it is safe to proceed.

If the user wants the result recorded, they — or the PM in a later, non-analysis step — can do that
separately; this command itself writes nothing.
