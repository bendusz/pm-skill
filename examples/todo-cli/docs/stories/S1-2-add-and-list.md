# S1-2 — add and list todos
Sprint: 1 · Priority: high · Depends on: S1-1 · Parallel-safe: no

## Goal
Implement the `add` and `list` subcommands on top of the S1-1 store.

## Context (self-contained)
- Extends `todo.py` from S1-1 (`load_store` / `save_store`, argparse with `add` / `list`).
- `add <text>` appends `text` to `todos` and saves (write-then-rename for safety).
- `list` prints each todo on its own line, in insertion order, 1-indexed.

## Acceptance criteria (testable)
- [ ] `todo add "buy milk"` appends "buy milk" to `todos.json`.
- [ ] `todo list` prints `1. buy milk` for a store with one item.
- [ ] `add` uses write-then-rename so an interrupted write can't corrupt the store.

## Out of scope
- Editing or deleting todos.

## Verification
- Prove done with: `python -m pytest -q test_todo.py`
