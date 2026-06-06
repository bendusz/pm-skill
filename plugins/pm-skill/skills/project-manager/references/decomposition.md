# Decomposition

Break the approved plan into sprints and **self-contained** story files.

## Sprints
- Group the plan's stories into sprints. Each sprint should deliver something independently
  valuable. Foundations first; later sprints build on earlier ones.

## Story files
For each story, create `docs/stories/S<sprint>-<n>-<slug>.md` containing **everything a builder
needs without reading the rest of the repo**:
- **Goal** (one paragraph).
- **Covers:** the spec requirement IDs (`FR-`/`AC-`) this story satisfies — the traceability link
  back to `docs/spec.md`.
- **Context (self-contained):** the architecture, files, interfaces, and conventions relevant to
  this story — summarised here so the worker's context stays small and focused.
- **Acceptance criteria** (testable checkboxes).
- **Out of scope.**
- **Touches:** the files/modules this story will change (or `—` if unknown) — used for `[P]` safety.
- **Risk & review lenses:** the story's `Risk` (low/med/high) and the review lenses it needs —
  `code-integrity-reviewer` always; add `architecture-reviewer` for structural change and
  `security-auditor` for security-sensitive surfaces. Declaring these (with `Security-sensitive` /
  `Architecture-sensitive`) lets `/pm-skill:analyze` check declared-vs-actual instead of guessing.
- **Verification:** the exact command(s) that prove the story is done.

(Use `${CLAUDE_PLUGIN_ROOT}/templates/story.md.template` as the shape.)

## Ordering
- Record each story's **depends-on**. Order so dependencies come first.
- Tag stories with no dependency on un-merged work as **`[P]`** (parallel-safe), and record each
  story's **Touches** (the files/modules it will change). The PM uses `[P]` + *non-overlapping*
  Touches to build several stories at once in isolated worktrees — see `parallel-execution.md`.
  When unsure, leave a story un-`[P]`; it simply runs sequentially.

## Story readiness (a story is build-ready only when…)
A story may be handed to the builder only once it passes this check:
- **testable acceptance criteria** are present (not vague),
- **requirement traceability** — `Covers:` names the spec IDs (`FR-`/`AC-`) it satisfies (where a spec exists),
- the **self-contained context** a cold worker needs is present (no "go read the repo"),
- a concrete **verification command** is given.
If a story fails the check, fix the story first — never dispatch the builder on an unready story.
(`${CLAUDE_PLUGIN_ROOT}/templates/checklist-story-readiness.md.template` is the full checklist.)

## Hand to the user
Show the sprint/story map so the user can see the shape. This is visible but not a hard gate —
sign-off already covered the plan. Log it, then load `implementation-loop.md`.
