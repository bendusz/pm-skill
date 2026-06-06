# Logging & State

Keep just enough state on disk that a lost session can resume with zero memory.

## `tmp/log.md` (gitignored — runtime state)
This is both the logbook and the recovery file. Keep it in this shape:

```
# PM Log — <project>

## Current State
- Objective: <one line>
- Spec: docs/spec.md — <clear | N clarifications open>
- Plan: docs/plan.md — APPROVED by <name> on <date>
- Sprint: <n> of <N> — "<goal>"
- Story: <id> "<title>" — <status>
- Verification: <pending | PASS | FAIL | UNKNOWN>
- Branch: <branch> (clean | N uncommitted)
- Next: <continuation point>

## Log
- <YYYY-MM-DD HH:MM> — <2–3 sentence summary of what happened>
```

- **Update the Current State block** whenever the sprint/story/branch changes.
- **Append a Log line** after every meaningful step. Write each entry *for a colleague with zero
  context* — short, concrete, no shorthand only you understand.
- `tmp/` is disposable; never rely on it for anything that must survive — that goes in committed
  artifacts.

## `tmp/pm-state.json` (gitignored — machine-readable state)
A small JSON companion to the prose log, so resume and tooling don't parse prose. The skill
maintains it (create it from `${CLAUDE_PLUGIN_ROOT}/templates/pm-state.json.template` when planning
begins): `phase`, `signed_off` (bool), `approver`, `approved_date`, `integration_branch`,
`current_sprint`/`total_sprints`, `current_story`/`current_story_status`, `branch`, `next`, `updated`,
and the optional spec-driven fields `spec`, `constitution`, `scale`, `last_analysis_status`, and
`current_story_verification_status`.
On the **parallel path** (`parallel-execution.md`), also keep `parallel_batch` — an array of
`{story, branch, worktree, commit, status}` (`building|built|in-review|merged|blocked`); on resume,
reconcile it against `git worktree list`, commit any dirty `building` worktree, and prune true orphans.

**`signed_off` is load-bearing:** the bundled sign-off hook reads it and blocks implementation writes
while it is `false`. Set it to `true` (with `approver` + `approved_date`) only at the sign-off gate.
Keep it in step with the prose log.

## Source of truth (committed)
The committed `docs/` artifacts are authoritative: `docs/spec.md` (product intent), `docs/plan.md` and
`docs/stories/*` (delivery), `docs/constitution.md` (project rules), and the optional `docs/checklists/*`
and `docs/verification/*`. `tmp/log.md` and `tmp/pm-state.json` only track *where you are*, not *what
was decided* — `tmp/` is disposable.

## On resume
When you re-enter a project (new session, or after `/compact`): **read `tmp/pm-state.json` and
`tmp/log.md` first** (the `/pm-skill:resume` command does exactly this). Reconstruct the objective,
current sprint/story, branch state, sign-off status, and the `next` pointer, then continue.
