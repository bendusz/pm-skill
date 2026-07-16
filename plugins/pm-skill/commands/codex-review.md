---
description: Spawn OpenAI Codex CLI review agents over the last commit, the working tree, or the whole codebase — optionally several focused objectives in parallel — and write reports to an untracked folder.
---

Run an independent **Codex CLI code review**. You orchestrate the `codex` binary (OpenAI's coding
agent CLI); you do not review the code yourself. Codex's reviewer is read-only by design — never
pass `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, or `--yolo`.

Arguments: $ARGUMENTS

## 1. Parse arguments

All optional, any order, from `$ARGUMENTS`:

- **scope** — `recent` | `worktree` | `codebase`. Default `worktree`.
- **model=<id>** — Codex model id (e.g. `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`).
  Default `gpt-5.6-terra`.
- **effort=<level>** — `minimal|low|medium|high|xhigh` (`max`/`ultra` only on models that
  support them). Default `high`.
- **timeout=<minutes>** — per-agent timeout. Default `10`.
- **objectives** — every remaining token. Presets: `security`, `bugs`, `architecture`, `tests`,
  `performance`; `panel` expands to all five. Any other word or quoted phrase is a **free-form
  objective**. Zero objectives → one general review.

Preset focus lines (use verbatim in prompts):

| Preset | Focus |
|---|---|
| security | authn/authz gaps, injection, secret handling, unsafe deserialization, dependency risk |
| bugs | logic errors, edge cases, error handling, race conditions, silent failures |
| architecture | module boundaries, coupling, abstraction fit, structural drift |
| tests | coverage of changed behavior, missing edge cases, assertion quality, flakiness risk |
| performance | algorithmic complexity, N+1 patterns, unnecessary allocation/IO, hot paths |

## 2. Preflight — stop with clear instructions on any failure

1. `command -v codex` — if missing, stop: install with `npm install -g @openai/codex` or
   `brew install codex`.
2. `codex login status` — non-zero exit means logged out; stop and tell the user to run
   `codex login` (or set `CODEX_API_KEY`). Never start an unauthenticated run — it burns ~20 s
   in retries before failing.
3. `git rev-parse --show-toplevel` — `recent` and `worktree` scopes require a git repo; stop if
   absent. `codebase` works without one (add `--skip-git-repo-check` to its command).
4. Scope sanity: `worktree` with a clean tree (`git status --porcelain` empty) or `recent` with
   no commit — report "nothing to review" and stop.

## 3. Output directory (at the repo root, or CWD when not a repo)

- If `untracked/` exists → candidate. Else `codex/` (create it) → candidate.
- In a git repo, the candidate must be genuinely ignored before use — a tracked directory must
  never receive reports (the review is advertised read-only; don't dirty the tree or overwrite
  project files):
  - `git ls-files -- <dir>` must be empty (appending to `.gitignore` does NOT ignore
    already-tracked files);
  - then ensure `grep -qxF '<dir>/' .gitignore 2>/dev/null || echo '<dir>/' >> .gitignore` and
    confirm with `git check-ignore -q <dir>`.
  - `untracked/` failing these checks → fall back to `codex/`; `codex/` also failing → stop and
    ask the user where reports should go.

Set `STAMP=$(date +%Y-%m-%d-%H%M)`. Report paths:
- single review → `<dir>/<STAMP>-codex-review-<scope>.md`
- per objective → `<dir>/<STAMP>-codex-review-<scope>-<objective-slug>.md`
  (slug: lowercase, spaces→hyphens, alphanumerics/hyphens only, ≤40 chars)
- index (only when ≥2 agents) → `<dir>/<STAMP>-codex-review-<scope>-index.md`

Collision safety: **dedupe objectives first** (`panel bugs` = the five presets once, not `bugs`
twice); if a report path already exists (rerun within the same minute), suffix `-2`, `-3`, … to
the whole run's filenames rather than overwriting.

## 4. Build each agent's command

Common tail for every invocation (`$MODEL`, `$EFFORT`, `$OUT` per agent):

```
-m "$MODEL" -c model_reasoning_effort="$EFFORT" --ephemeral -o "$OUT"
```

Do not pass `--color`, `--sandbox`, or `-C` to `codex exec review` — it rejects them (exit 2);
they exist only on plain `codex exec`.

**No objectives** (one general review; native scope flags):
- `recent` → `codex exec review --commit HEAD <tail>`
- `worktree` → `codex exec review --uncommitted <tail>`
- `codebase` → `codex exec --sandbox read-only --skip-git-repo-check <tail> "<codebase prompt>"`

**With objectives** — one agent per objective. Prefer native target flags whenever no custom
objective is required; prompt-as-scope below is a deliberate capability fallback, not an
interchangeable style: the CLI forbids combining a custom prompt with a native scope flag, so the
prompt must restate the target precisely:
- `recent` → `codex exec review <tail> "Review the changes introduced by the last commit (HEAD). <objective clause>"`
- `worktree` → `codex exec review <tail> "Review the uncommitted changes — staged, unstaged, and untracked. <objective clause>"`
- `codebase` → `codex exec --sandbox read-only --skip-git-repo-check <tail> "<codebase prompt> <objective clause>"`

Objective clause — presets: `Focus exclusively on <preset focus line>.`; free-form:
`Focus exclusively on this objective: <text>.` Always append:
`Report prioritized findings with file:line references and a severity (critical/major/minor) for each, then a short overall verdict.`

Codebase prompt: `Perform a thorough code review of the entire codebase in the current directory. First survey the architecture and conventions, then review the most important modules in depth.`

## 5. Run

From the repo root (`codex review` accepts no `-C`), launch every agent **in parallel in the
background**, redirecting each agent's stderr to a sidecar `<report-path>.stderr.log`. Then wait,
enforcing the timeout: poll every ~30 s; kill any agent still running after `timeout` minutes and
mark it `TIMEOUT`.

Exit codes: `0` success · `1` runtime/auth failure · `2` CLI usage error (a bug in the command you
built — read the sidecar log). Delete an agent's sidecar log on success; keep it on failure and
say so.

One agent failing never discards the others — always collect partial results.

## 6. Report

- **≥2 agents:** write the index file with a run-metadata table (date, scope, model, effort,
  timeout) and one row per objective: objective, exit status (`OK`/`FAIL`/`TIMEOUT`), report
  path, and a one-line summary of its top finding. The per-objective reports are Codex's `-o`
  output, untouched.
- **1 agent:** the `-o` file is the report; no index.
- If `pm/log.md` exists, append one line:
  `- <STAMP> codex-review <scope> [objectives] → <n> report(s) in <dir>/`.

Finish by telling the user: each report path, and the top findings per objective (read the
report files — do not paraphrase from memory). If every agent failed, say exactly why (auth,
timeout, usage error) and where the sidecar logs are.
