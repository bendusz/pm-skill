# Planning & Sign-off

Turn the agreed direction into a written plan, get explicit human sign-off, then scaffold.

## 1. Write `docs/plan.md`
Create `docs/plan.md` with these sections:
- **Overview** — what + why, 2–3 sentences.
- **Goals** and **Target users**.
- **Scope** — In / Out (be explicit about what you are *not* doing).
- **Stories** — a table: `| id | title | priority | acceptance criteria | depends-on | [P] |`.
  Acceptance criteria must be **testable**.
- **Architecture** — stack, key decisions, patterns.
- **Non-functional requirements** — performance, security, etc.
- **Commands** — the project's real `test` / `lint` / `build` / `run` commands. If one does not
  exist, write `N/A` (you'll honour that in the gates later). Discover these now.
- **Risks** and any open questions.
- **Clarifications** — must be **empty** before sign-off.
- **Sign-off** — a line to be filled: `Approved by <name> on YYYY-MM-DD`.

Present it. Iterate with the user until they're happy.

## 2. Sign-off gate (procedural — you enforce it by discipline)
Get an **unambiguous human "approved"**. Record the approver and date in the plan's Sign-off line
and in `tmp/log.md`. **Do not decompose or write any code before this.** There is no hook stopping
you in v1 — holding this line is your responsibility.

## 3. Scaffold (only after sign-off) — observe Repository safety
- If the project is **not** a git repo, offer to `git init` — **ask first**.
- Generate a project `CLAUDE.md` from the template. If one **already exists**, do **not** overwrite
  it — show a diff and ask, or append a clearly-marked section.
- Ensure `.gitignore` includes `tmp/` (append; don't clobber an existing `.gitignore`).
- Commit **only** the files you created/changed (no `git add -A` over the user's other work).
- If git has no `user.name`/`user.email`, ask before committing.

Log the scaffold step. Then load `decomposition.md`.
