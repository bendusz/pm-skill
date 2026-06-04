---
description: Resume a PM-managed project — read the saved state and logbook, then continue.
---

Use the `project-manager` skill to resume work on this project.

First read `tmp/pm-state.json` (current phase, sprint/story, branch, sign-off status, and the
`next` step) and `tmp/log.md` (the chronological logbook). Summarise for the user where things
stand, then continue from the recorded `next` step.

If neither file exists, there is nothing to resume — start from discovery instead.
