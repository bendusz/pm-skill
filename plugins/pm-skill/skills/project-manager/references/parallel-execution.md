# Parallel Execution (`[P]` stories)

An **opt-in, best-effort** fast path: build several independent stories at once in isolated git
worktrees, then integrate them **one at a time**. If anything is unavailable or goes wrong, fall back
to the sequential `implementation-loop.md`. Every git rule from the hard rules still holds.

**Why it's safe:** builders **make no commits** (you own git). The concurrent phase is pure
file-editing in separate directories — **zero git writes** — so there's no shared-`.git` contention.
All git operations (worktree add/remove, commit, merge) are **yours, and serial**.

## 1. Choose the parallel batch (at sprint start)
A batch = stories in the sprint that are all of:
- **build-ready** (see `decomposition.md`), and marked **`[P]`**, and
- their `depends-on` are **already merged**, and
- they **don't share a file domain** — compare each story's **Touches** (the files/modules it will
  change). If two would write the same files, **serialize those** (run one in this batch, the other
  after) — overlapping writes are where "independent" stories collide.

Need **≥2** stories after that filter, and `git worktree` must work. Otherwise just run the
sequential loop. **Cap concurrency** (default **3**, raise only with care — conflict/coordination
cost grows roughly with the square of the batch size); run a larger set in waves.

## 2. Build phase — parallel, edit-only
Prefer the host's **native worktree isolation** if it offers it. Otherwise, per story:
- `git worktree add tmp/worktrees/<slug> -b pm/S<sprint>-<n>-<slug> <integration_branch>`
  (ensure `tmp/` — and so `tmp/worktrees/` — is gitignored first).
- Dispatch the batch's builders **together** (concurrent subagent calls in one step), giving each
  **only its story file path + its worktree path**. Tell each to **implement and self-check only —
  not run the full or exclusive test suite** (you run the authoritative gates serially next; this
  avoids parallel builders colliding on shared ports/DBs). Take back only structured summaries.
- When a builder returns done, **commit that story's edits to its story branch** (story-path-scoped;
  **never `git add -A`**) so the work is captured before any worktree is touched.

If the host serializes the dispatch, isolation still holds — you lose only the wall-clock win.

## 3. Integration tail — serial (FIFO / priority; real dependencies first)
Take one story at a time and land it before starting the next:
1. **Bring the latest integration tip into the story branch** (merge or rebase it up to date).
2. **Run the authoritative gates** on that combined result (test/lint/build per `review-gates.md`).
   This is where a **semantic conflict** surfaces — two stories that each passed alone but break
   together. (Optionally enable `git rerere` so repeated conflict resolutions are remembered.)
3. **Review + fix** exactly as in the sequential loop: story-scoped diff → risk-selected panel →
   triage → fix via the builder, **≤3 rounds** (dispatch `debugger` first when a gate fails or a
   round stalls), re-gating each round.
4. On green with no open `block`/`major`: `--no-ff` merge the story branch into the integration
   branch (**local by default; remote only on explicit request**). **Log** the outcome.
5. **Remove the worktree** now that the work is committed and merged.

A **blocked** story escalates per the normal cap **without blocking the rest**. A partial batch still
checkpoints at the sprint boundary.

## Worktree safety (non-negotiable)
- **Capture before cleanup:** commit a story's edits to its branch *before* removing its worktree.
- Remove only with **`git worktree remove`** — **never `rm -rf`**. **Never force-remove a worktree
  with uncommitted changes** (check `git -C <wt> status --porcelain` first; preserve and report).
- **No orphans:** clean up every worktree you created — on success *or* on error/interruption. Sweep
  with `git worktree prune` when you enter or resume a project.
- Give every worktree its **own** branch (git refuses to check the same branch out twice — don't
  `--force` past it). **Don't run `git gc`** while worktrees are active.
- The sign-off hook fail-opens inside a worktree (no `tmp/pm-state.json` there); that's fine —
  worktrees exist only after sign-off, when `signed_off` is already `true`.

## State & resume
Track the batch in `tmp/pm-state.json` `parallel_batch` (each `{story, branch, worktree, status}`;
status `building|built|in-review|merged|blocked`). On resume, reconcile it against `git worktree
list` and `tmp/log.md`, prune orphans, then continue the integration tail.

## Fallback (always available)
Parallel is never required. If worktrees are unsupported, setup fails, or a story misbehaves mid
flight, finish it on the sequential `implementation-loop.md`. Sequential is the default and the net.
