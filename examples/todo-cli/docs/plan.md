# todo-cli — Delivery Plan

## Overview
A tiny command-line tool to add todos and list them, persisted to a local JSON file. Built to
demonstrate the pm-skill workflow end to end.

## Goals
- Add a todo from the command line.
- List existing todos.

## Target users
- A developer who wants a minimal local todo list.

## Scope
**In:**
- `todo add "<text>"` and `todo list`.
- JSON-file persistence in the working directory.

**Out:**
- Due dates, priorities, editing, deletion, sync.

## Stories
| id | title | priority | acceptance criteria | depends-on | [P] |
|------|----------------------|----------|--------------------------------------------------|------------|-----|
| S1-1 | CLI skeleton + store | high | `todo` runs; an empty store is created/read       | none | no |
| S1-2 | add and list todos   | high | `add` appends; `list` prints them in order        | S1-1 | no |

## Architecture
Single Python module `todo.py` with an `argparse` CLI and a small store helper reading/writing
`todos.json`. No external dependencies.

## Non-functional requirements
- No third-party packages; Python 3.10+.

## Commands
- test: `python -m pytest -q`
- lint: `N/A`
- build: `N/A`
- run: `python todo.py`

## Risks
- JSON file corruption if interrupted mid-write — mitigate with write-then-rename.

## Clarifications
<!-- empty -->

## Sign-off
Approved by bendusz on 2026-06-04
