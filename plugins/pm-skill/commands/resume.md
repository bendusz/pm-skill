---
description: Resume a PM-managed project — read the saved state and logbook, then continue.
---

Use the `project-manager` skill to resume work on this project.

First read `pm/pm-state.json` (current phase, sprint/story, branch, sign-off status, the loop
counters `current_story_rounds`/`current_story_retries` — the fix/retry caps count what earlier
sessions already spent — and the `next` step). If `pm/HANDOFF.md` exists and is current
(`updated` is not newer than `handoff_written` in the state), use it as the primary briefing — it carries the in-flight detail,
decisions, gotchas, `READ_FIRST`/`SKIP` pointers, and ordered next steps, and it exists precisely so
you don't re-read the whole project. Fall back to `pm/log.md` (the chronological logbook) for
anything the handoff doesn't cover, or when the handoff is stale or absent. Summarise for the user
where things stand, then continue from the recorded `next` step.

**Migration (pre-0.8 projects):** if `pm/` does not exist but the old `tmp/pm-state.json` /
`tmp/log.md` (and `tmp/HANDOFF.md`, if present) do — move those files into a new tracked `pm/`
directory first, leave a one-line pointer stub in `tmp/` for each (`Moved to pm/<name>`), update any
repo references to the old paths (`CLAUDE.md`, docs, code comments), verify
`git check-ignore pm/pm-state.json pm/log.md` fails (check the files, not the directory) while
`tmp/` stays ignored, and commit. Then resume as above.

If no state file exists in either location, there is nothing to resume — start from discovery instead.
