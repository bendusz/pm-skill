# Worked example — `todo-cli`

An **illustrative** walkthrough of what `pm-skill` produces for a small project ("a CLI to add and
list todos"). These files are **not executed** — they show the *shape* of the artifacts the PM
writes into a real project:

- `todo-cli/docs/plan.md` — the signed-off delivery plan.
- `todo-cli/docs/stories/` — two self-contained story files.
- `todo-cli/CLAUDE.md` — the generated project memory (workflow rules first).
- `todo-cli/tmp/pm-state.json` — machine-readable state (a mid-run snapshot).
- `todo-cli/tmp/log.md` — the recovery logbook (a mid-run snapshot).

In a real run these live in *your* project, and `tmp/` is gitignored.
