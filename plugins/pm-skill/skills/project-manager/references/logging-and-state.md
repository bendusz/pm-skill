# Logging & State

Keep just enough state on disk that a lost session can resume with zero memory.

## `tmp/log.md` (gitignored — runtime state)
This is both the logbook and the recovery file. Keep it in this shape:

```
# PM Log — <project>

## Current State
- Objective: <one line>
- Plan: docs/plan.md — APPROVED by <name> on <date>
- Sprint: <n> of <N> — "<goal>"
- Story: <id> "<title>" — <status>
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

## Source of truth (committed)
`docs/plan.md` and `docs/stories/*` are version-controlled and authoritative. `tmp/log.md` only
tracks *where you are*, not *what was decided*.

## On resume
When you re-enter a project (new session, or after `/compact`): **read `tmp/log.md` first.**
Reconstruct the objective, current sprint/story, branch state, and the "Next" pointer, then
continue from there.
