# todo-cli — Project Memory

## Workflow rules (non-negotiable)
- Never implement before the human approves the plan.
- The PM orchestrates and does not write code — implementation is done by subagents.
- Log progress to `tmp/log.md` after every meaningful step.
- The project's gates (test/lint/build) must pass before a story is marked done.

## Project
A minimal CLI to add and list todos, persisted to `todos.json`. Python 3.10+, standard library only.

## Commands
- Test: `python -m pytest -q`
- Lint: `N/A`
- Build: `N/A`
- Run: `python todo.py`

## Architecture & layout
- `todo.py` — argparse CLI + JSON store (`load_store` / `save_store`).
- `test_todo.py` — pytest tests.
- `todos.json` — the store (created at runtime; gitignored).

## Conventions
- Standard library only. Write-then-rename for any file write.

## Gotchas
- Don't commit `todos.json` or `tmp/`.
