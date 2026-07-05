# Logging & State

Keep just enough state on disk that a lost session can resume with zero memory.

## The layout: `pm/` is tracked, `tmp/` is scratch
- **`pm/` (git-tracked, committed):** the durable PM state — `pm/pm-state.json`, `pm/log.md`, and
  the optional `pm/HANDOFF.md`. This trio is the project's resume point; losing the checkout must
  not lose it, so it lives in git and travels with every clone and push.
  Verify the state files are **not** matched by `.gitignore` when you create the directory:
  `git check-ignore pm/pm-state.json pm/log.md` must fail. Check the *files*, not just `pm/` — a
  `pm/*` or `pm/*.json` ignore rule still ignores the files while a directory check passes.
- **`tmp/` (gitignored, disposable):** everything ephemeral — scratch files, prompt drafts, raw
  subagent/review output, diffs, CI log dumps, one-off scripts, `tmp/environment-check.md`,
  `tmp/worktrees/`. It can accumulate tens of MB; none of it may enter git history, and **nothing in
  `tmp/` may be load-bearing for resume** — anything that must survive goes in `pm/` or `docs/`.

**Commit `pm/` with the work it describes.** Update the state files as you go, and include them in
the ship/log commit for each story (and in the sign-off and sprint-boundary commits), so the pushed
repo always carries the current resume point. Don't let `pm/` drift uncommitted across story
boundaries.

**No secrets — load-bearing rule.** `pm/` is tracked, so secrets/credentials must **never** be
written into `pm/pm-state.json`, `pm/log.md`, or `pm/HANDOFF.md` — reference secret *locations*
(e.g. "`.env` on the box"), never values. The bundled `pm-secrets-guard.sh` hook blocks
secret-shaped content from entering `pm/` as a mechanical backstop, but it only catches
high-confidence token shapes — the rule is yours to hold.

## `pm/log.md`
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

## `pm/pm-state.json`
A small JSON companion to the prose log, so resume and tooling don't parse prose. The skill
maintains it (create it from `${CLAUDE_PLUGIN_ROOT}/templates/pm-state.json.template` when planning
begins): `phase`, `signed_off` (bool), `approver`, `approved_date`, `integration_branch`,
`current_sprint`/`total_sprints`, `current_story`/`current_story_status`, `branch`, `next`, `updated`,
and the optional spec-driven fields `spec`, `constitution`, `scale`, `last_analysis_status`, and
`current_story_verification_status`.
**Bound counters:** `current_story_rounds` (fix/re-review rounds used) and `current_story_retries`
(builder retries used) persist the loop bounds across sessions — reset both to `0` when a story
starts, increment as rounds/retries are spent, and honour the ≤3-round / ≤2-retry caps **including**
what a previous session already used. A resumed session never gets fresh bounds for free.
`handoff_written` holds the timestamp of the last `/pm-skill:handoff` (see below).
On the **parallel path** (`parallel-execution.md`), also keep `parallel_batch` — an array of
`{story, branch, worktree, commit, status}` (`building|built|in-review|merged|blocked`); on resume,
reconcile it against `git worktree list`, commit any dirty `building` worktree, and prune true orphans.

**`signed_off` is load-bearing:** the bundled sign-off hook reads it and blocks implementation writes
while it is `false`. Set it to `true` (with `approver` + `approved_date`) only at the sign-off gate.
Keep it in step with the prose log.

## `pm/HANDOFF.md` (optional — end-of-session briefing)
Written by `/pm-skill:handoff` when the user ends a run, from
`${CLAUDE_PLUGIN_ROOT}/templates/HANDOFF.md.template`. It is **agent-to-agent** and token-efficient
by design: terse key-value lines, pointers (`READ_FIRST`/`SKIP`) instead of restated content, and
only what a fresh agent can't cheaply rediscover — in-flight story state, last gate results, open
findings, decisions not yet in docs, gotchas, blockers, ordered next steps. **Overwrite** it on each
handoff (one moment in time; history is `pm/log.md` + git) and commit it with the other `pm/` files.
The command records the write time in `pm-state.json` `handoff_written`. On resume it is read right
after `pm/pm-state.json`; if `updated` is newer than `handoff_written`, work moved on after the
handoff — it is stale, trust state + log instead.

## Source of truth (committed)
The committed `docs/` artifacts are authoritative for decisions: `docs/spec.md` (product intent),
`docs/plan.md` and `docs/stories/*` (delivery), `docs/constitution.md` (project rules), and the
optional `docs/checklists/*` and `docs/verification/*`. `pm/log.md` and `pm/pm-state.json` track
*where you are*, not *what was decided* — but they are tracked too, because the resume point must
survive the checkout.

## On resume
When you re-enter a project (new session, or after `/compact`): **read `pm/pm-state.json` and
`pm/log.md` first** (the `/pm-skill:resume` command does exactly this; the bundled
`session-context.sh` SessionStart hook also injects a short pm/-state pointer into every new or
freshly-compacted session automatically). Reconstruct the objective,
current sprint/story, branch state, sign-off status, and the `next` pointer, then continue.

### Migrating a pre-0.8 project (state still under `tmp/`)
On any state read, if the old `tmp/pm-state.json` / `tmp/log.md` (and `tmp/HANDOFF.md`, if present)
exist but `pm/` does not:
1. Create `pm/` and **move** the state files there; verify `git check-ignore pm/pm-state.json
   pm/log.md` fails (check the files, not the directory; if a `.gitignore` rule matches them, fix
   the rule) and that `tmp/` is still ignored.
2. Leave a one-line pointer stub in `tmp/` for each moved file (e.g. `Moved to pm/pm-state.json`).
3. Update any repo references to the old paths (`CLAUDE.md`, docs, code comments).
4. Commit the new `pm/` files and the reference updates, then continue from the recorded `next` step.
