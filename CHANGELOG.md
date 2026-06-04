# Changelog

All notable changes to this project are documented here.

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
