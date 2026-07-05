---
description: Check environment readiness before implementation — tooling, versions, and whether the project's gates actually run.
---

Use the `project-manager` skill to run a pre-implementation **environment readiness** check. This is
read-mostly: inspect and probe, do not modify project files.

Scope: $ARGUMENTS  (optional — a sub-path or component; default is the whole repo)

Inspect (whichever apply):
- **Toolchain & versions:** the language runtime(s), package manager, and their versions.
- **Dependencies:** lockfiles present; whether install has been run (e.g. `node_modules`, a venv).
- **Gates:** the `test` / `lint` / `build` / `run` commands from `docs/plan.md` / `CLAUDE.md`, and
  whether each actually **runs** — a non-mutating probe (`--version`/help, or the real command only if
  it is safe and fast). Record `N/A` for ones the project doesn't have.
- **Config:** a missing `.env.example` or required env vars; CI config.
- **Containers:** a `Dockerfile` / devcontainer that defines the expected environment.
- **Setup steps:** any documented bootstrap (README/CONTRIBUTING) needed before the gates pass.
- **PM state health** (when `pm/` exists — report `OK` / `DRIFT` per check):
  - `pm/pm-state.json` parses as JSON (`jq empty` or equivalent).
  - `git check-ignore pm/pm-state.json pm/log.md pm/actors/<you>.json` **fails** — check the state
    *files*, not the directory (a `pm/*` ignore rule passes a directory check while still ignoring
    the files) — and `tmp/` **is** ignored; `pm/` has no uncommitted changes older than the last
    work commit; `.gitattributes` carries `pm/log.md merge=union`.
  - **Team health:** every `assignments` story maps to exactly one actor with a matching story
    branch (flag double-claims and stale claims — an assignment whose actor has no branch or
    recent activity); every `pm/actors/*.json` parses and matches a recent git author (flag
    orphans from a changed git identity); your own actor id is derivable (git `user.email` /
    `user.name` set).
  - `docs/plan.md`'s Sign-off line agrees with `signed_off` in `pm/pm-state.json` (the v0.9 log is
    append-only and has no Current State block to cross-check).
  - `handoff_written` vs `updated` in `pm/actors/<you>.json`: flag a stale
    `pm/actors/<you>.HANDOFF.md` (updated is newer) so resume doesn't trust an outdated briefing.

Stay read-only where you can and run only **non-mutating** probes. Do **not** install, upgrade, or
write project files (delegate heavy reading to a read-only subagent if useful).

Write the findings to `tmp/environment-check.md` (runtime-only): each check → `OK` / `MISSING` /
`UNKNOWN` with the evidence, then a one-line verdict (ready / blockers + what's missing). Append a
one-line entry to `pm/log.md`.

Run this before the implementation loop on an unfamiliar or freshly-cloned project — environment and
dependency gaps are a common cause of mid-build failure.
