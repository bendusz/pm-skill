# Changelog

All notable changes to this project are documented here.

## 0.5.0 — 2026-06-04

Parallel `[P]` story execution via git worktrees — opt-in, best-effort, with a hard fallback to the
sequential loop.

- New `references/parallel-execution.md`: build independent `[P]` stories at once in isolated git
  worktrees, then integrate them **one at a time** (concurrent build, serialized integration — the
  model behind merge queues / merge trains / the "Not Rocket Science Rule").
- Safe because builders make no commits (the PM owns git): the concurrent phase does zero git writes,
  so there's no shared-`.git` contention. Before each land, the latest integration tip is merged in
  and the full gates re-run — catching semantic conflicts two "independent" stories can create.
- Decomposition records each story's **Touches** (files/modules); `[P]` + non-overlapping Touches
  selects the batch. Default fan-out 3 (configurable). `tmp/worktrees/` (gitignored); native
  worktree isolation preferred when the host offers it.
- Worktree safety: never `rm -rf`, never force-remove a dirty worktree, no orphans (prune on
  resume). `pm-state.json` gains a `parallel_batch` array for resume. Same gates/review panel as
  sequential.

## 0.4.0 — 2026-06-04

More delivery agents and optional model tiering. All additive — defaults unchanged.

- New bundled agents: `security-auditor` (read-only deep security lens, risk-selected),
  `technical-writer` (docs only — README, usage, CHANGELOG, completion report), and `debugger`
  (read-only root-cause diagnosis → fix plan the builder applies).
- `security-auditor` is now a first-class risk-triggered lens in the review panel
  (`review-gates.md`); `debugger` joins the fix loop when a gate fails or it stalls; an optional
  Document step adds `technical-writer` at the sprint/project boundary.
- **Optional model tiering** (`references/model-tiering.md`) — map agents to cheaper/stronger models
  by abstract tier (deep / standard / light). Off by default; every agent still inherits the session
  model and no vendor model IDs are hardcoded.
- New `completion-report.md.template`.

## 0.3.0 — 2026-06-04

Hardening: enforcement, recoverable state, CI, and a worked example.

- **Sign-off enforcement hook** (`hooks/`) — a fail-open `PreToolUse` hook that blocks implementation
  writes until `tmp/pm-state.json` has `signed_off: true`. Inert outside a PM project; kill switch
  `PM_SKILL_NO_ENFORCE=1`.
- **Structured state + resume** — `tmp/pm-state.json` and the `/pm-skill:resume` command.
- **Story-readiness check** before build, and **reviewer-finding triage** before the fix loop.
- **Worked example** under `examples/todo-cli/`.
- **CI + OSS hygiene** — `scripts/validate.sh`, a validate workflow, CONTRIBUTING, and issue/PR templates.

## 0.2.0 — 2026-06-04

Delivery agents and risk-based review.

- New bundled agents: `codebase-analyst` (read-only context pack), `test-engineer` (tests only),
  `architecture-reviewer` (read-only design lens).
- Review generalised into a risk-selected **panel** (`review-gates.md`): always run
  `code-integrity-reviewer`; add `architecture-reviewer` for structural changes.
- Planning gains an optional `codebase-analyst` analyze step for brownfield projects.

## 0.1.0 — 2026-06-02

Initial release.

- `project-manager` skill: discover → plan → sign-off → decompose → orchestrate → review → ship → log.
- Bundled agents: `expert-builder` (implementation) and `code-integrity-reviewer` (read-only review).
- `/pm-skill:pm` command entry.
- Target-project templates: `CLAUDE.md`, `plan.md`, `story.md`, `log.md`.
- Sprint-level checkpoints (configurable); `tmp/log.md` recovery; repository-safety rules.
