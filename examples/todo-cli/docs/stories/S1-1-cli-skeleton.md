# S1-1 — CLI skeleton + store
Sprint: 1 · Priority: high · Depends on: none · Parallel-safe: no

## Goal
Stand up the `todo.py` entry point with an `argparse` CLI and a JSON store that reads an existing
`todos.json` or starts empty.

## Context (self-contained)
- New file `todo.py` at the project root. Python 3.10+, standard library only.
- Store lives in `todos.json` in the current directory; shape: `{"todos": ["text", ...]}`.
- Use `argparse` with two subcommands to be filled in S1-2 (`add`, `list`); for now wire the parser
  and a `load_store()` / `save_store()` pair.
- Tests in `test_todo.py` using `pytest`.

## Acceptance criteria (testable)
- [ ] `python todo.py` exits 0 and prints usage when no subcommand is given.
- [ ] `load_store()` returns `{"todos": []}` when `todos.json` is absent.
- [ ] `save_store()` then `load_store()` round-trips data.

## Out of scope
- The actual add/list behaviour (S1-2).

## Verification
- Prove done with: `python -m pytest -q test_todo.py`
