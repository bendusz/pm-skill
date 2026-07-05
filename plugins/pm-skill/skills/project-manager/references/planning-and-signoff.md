# Planning & Sign-off

Turn the agreed direction into a written plan, get explicit human sign-off, then scaffold.

## 0. Analyze existing code (brownfield — optional)
If you're working in an existing codebase, dispatch `codebase-analyst` first. Fold its context pack
into the plan's Architecture and Commands sections, and keep it to embed into story files later.
Skip this for a greenfield project.

## 1. Write `docs/plan.md`
If `docs/spec.md` exists, the plan **derives from it** — turn its requirements into delivery work and
trace each story back to the spec's IDs. (No spec yet? Run `/pm-skill:specify` first for non-trivial
work, or fold the intent straight into the plan for something small.)

Initialise `pm/pm-state.json` from `${CLAUDE_PLUGIN_ROOT}/templates/pm-state.json.template`
(`signed_off: false`) if it doesn't exist yet. `pm/` is **git-tracked**: create the directory,
verify the state files are not matched by `.gitignore` (`git check-ignore pm/pm-state.json
pm/log.md` must fail — check the files, not just the directory, since a `pm/*` rule ignores the
files while the directory check passes; fix the rule if anything matches), and commit `pm/` from
the first state write onward (see `logging-and-state.md`; never write secrets into it). Then create `docs/plan.md` with these sections:
- **Overview** — what + why, 2–3 sentences.
- **Source spec** — link `docs/spec.md` (or note "none — intent captured inline").
- **Goals** and **Target users**.
- **Scope** — In / Out (be explicit about what you are *not* doing).
- **Stories** — a table: `| id | title | priority | covers | acceptance criteria | depends-on | [P] |`.
  Acceptance criteria must be **testable**; `covers` lists the spec IDs (`FR-`/`AC-`) each story satisfies.
- **Architecture** — stack, key decisions, patterns.
- **Traceability** — every spec requirement maps to at least one story (flag any that don't).
- **Non-functional requirements** — performance, security, etc.
- **Commands** — the project's real `test` / `lint` / `build` / `run` commands. If one does not
  exist, write `N/A` (you'll honour that in the gates later). Discover these now.
- **Risks** and any open questions.
- **Clarifications** — must be **empty** before sign-off (here and in `docs/spec.md`).
- **Sign-off** — a line to be filled: `Approved by <name> on YYYY-MM-DD`.

Present it. Iterate with the user until they're happy. For a larger project, run `/pm-skill:analyze`
before decomposition — optionally on the drafted plan before you record sign-off — for a read-only
consistency and coverage check (the Stories table carries the `covers` mapping); resolve any
CRITICAL/HIGH findings first.

## 2. Sign-off gate
Sign-off requires all three: **no blocking `[NEEDS CLARIFICATION]`** in `docs/spec.md` (or the plan),
`docs/plan.md` **present**, and an **unambiguous human "approved"**. Record the approver and date in
the plan's Sign-off line, in `pm/log.md`, and set `signed_off: true` (with `approver` +
`approved_date`) in `pm/pm-state.json`. **Do not decompose or write any code before this.** The bundled sign-off hook
enforces it — blocking implementation writes while `signed_off` is `false` — but it is fail-open and
can be disabled, so holding the line is still your responsibility.

## 3. Scaffold (only after sign-off) — observe Repository safety
- If the project is **not** a git repo, offer to `git init` — **ask first**.
- Generate a project `CLAUDE.md` from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template`. If one
  **already exists**, do **not** overwrite it — show a diff and ask, or append a clearly-marked section.
- Ensure `.gitignore` includes `tmp/` (append; don't clobber an existing `.gitignore`) — `tmp/` is
  ephemeral scratch and never enters git. The tracked `pm/` state files must **not** be ignored
  (`git check-ignore pm/pm-state.json pm/log.md` must fail).
- Commit **only** the files you created/changed (no `git add -A` over the user's other work).
- If git has no `user.name`/`user.email`, ask before committing.
- The branch the scaffold commit lands on (default `main`) is the **integration branch** — the
  base you cut every story branch from and merge each story back into.

Log the scaffold step. Then load `decomposition.md`.
