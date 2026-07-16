# Implementation Loop

Run each story through this loop. **You orchestrate; you do not write code.** Take only summaries
back — never raw transcripts (protect your context).

The **integration branch** is the project's default branch (e.g. `main`) that the scaffold commit
landed on. You cut every story branch from it and merge each story back into it.

**Before the first sprint on an unfamiliar or freshly-cloned project, run `/pm-skill:doctor`** —
confirm the toolchain installs and the gates actually run, so stories don't fail mid-build on
environment gaps.

## Sequential or parallel? (decide at the start of each sprint)
- **Parallel fast path** — if the sprint has **≥2** build-ready `[P]` stories whose `depends-on` are
  merged and whose **Touches** don't overlap, and `git worktree` works: build them at once in
  isolated worktrees and integrate them serially. Load `parallel-execution.md`.
- **Sequential (default)** — otherwise, run the per-story cycle below, one story at a time.

Parallel is opt-in and best-effort; on any worktree trouble, fall back to sequential. Either way each
story is judged by the **same** deterministic gates and review panel below.

## Per-story cycle
0. **Ready & branch.** Confirm the story is **build-ready** (testable criteria + self-contained
   context + a verification command — see `decomposition.md`); if not, fix the story first. Ensure
   the working tree is **clean** (if it has unrelated changes, stop and ask — see Repository
   safety). **Claim the story — one commit on the integration branch:** pull/rebase it first,
   confirm no other actor holds the story in `assignments` (if one does, pick another story or
   resolve with them), then set `assignments["<story-id>"] = <you>` in `pm/pm-state.json` **and
   record your position** in `pm/actors/<you>.json` — `current_story`, `current_story_status`
   (`building`), `branch` (the planned story branch name), `next`, `updated`, and
   `current_story_rounds`/`current_story_retries` reset to `0` — and commit **both files
   together**. (A claim committed only to a story branch is invisible to teammates'
   pull-integration-and-check flow, and an assignment without the matching actor position reads
   as a stale claim to doctor/analyze.) Push it only under the user's standing push permission —
   **never push without an explicit request** (hard rule); without pushes, tell the user the
   claim stays local-only until pushed. Then create and check out the story branch
   `pm/S<sprint>-<n>-<slug>` — all of this story's work happens there. Resume and the session
   hook read position from the actor file (the shared state no longer carries it), and the loop
   bounds below are enforced from the persisted counters, not from memory, so everything
   survives a session loss mid-story.
1. **Build.** *(Optional, for clear acceptance criteria: first dispatch `test-engineer` to write the
   acceptance tests — TDD red. Then tell the builder those tests already exist: it must make them
   pass and add only *further* coverage, not rewrite them.)* Dispatch `expert-builder`
   with **only the story file path** (it reads the project `CLAUDE.md` itself). It edits the working
   tree (no commits — you own git) and returns a structured summary, including the **list of files it
   changed**. If it returns *blocked* or fails, retry up to **2** times with clarification —
   incrementing `current_story_retries` in `pm/actors/<you>.json` per retry (the cap counts retries
   already spent by a previous session) — then escalate to the user.
2. **Gate.** Run the project's deterministic gates yourself (test/lint/build per
   `review-gates.md`; skip any that are `N/A`). If a gate fails, go to Fix (step 4) before review.
3. **Review.** Produce the diff yourself and pass it to the reviewers inline — they have no Bash and
   cannot diff. Diff **only the story's changed paths** (from the builder's summary), e.g.
   `git add -N -- <changed paths> && git diff -- <changed paths>` — **never `git add -A`** (that
   would sweep in unrelated work). Dispatch the **review panel** per the risk triggers in
   `review-gates.md`: always `code-integrity-reviewer`, plus any further lenses it selects (e.g.
   `architecture-reviewer` for structural changes — also give it the plan's Architecture section).
   Each lens gets the story file + that diff text and returns severity-graded findings
   (`block`/`major`/`minor`) and a `PASS`/`CONCERNS`/`FAIL` verdict; aggregate them.
4. **Fix.** First **triage** the panel's findings — dedupe across lenses and drop false positives /
   out-of-scope items, so you forward only real `block`/`major` findings. Send those back to
   `expert-builder`. If a **gate** is failing (rather than a review finding), or the builder returns
   the same failing result on a second attempt (no meaningful progress), dispatch `debugger` first to
   root-cause it — give it the failing command's output, the
   diff, and the implicated paths — then forward its fix plan to `expert-builder` instead of a blind
   retry (`debugger` is read-only; the builder applies the fix). After each fix, **re-run the gates
   and regenerate the diff for re-review**, **up to 3 rounds** — increment `current_story_rounds`
   in `pm/actors/<you>.json` as each round starts; the cap counts rounds already spent by a previous
   session — and if still failing, **escalate to the user**.
5. **External review (optional).** Only if an external reviewer is **explicitly available**:
   secret-scan the **exact outgoing diff** first — prefer a real scanner when one is installed
   (`gitleaks`, `trufflehog`); otherwise pipe the diff through the bundled value patterns:
   `git diff <range> | ${CLAUDE_PLUGIN_ROOT}/hooks/lib.sh scan` (non-zero exit = secret-shaped
   content). If it trips, do **not** send code out. (Scan values, not labels — a name like
   `APIClient` is not a secret, and real credentials are often lowercase.) Then an independent review → feed findings back → fix. If no
   external reviewer is available, **log that it was skipped** — never silently.
6. **Verify.** Before shipping, dispatch `pm-verifier` (read-only) to independently confirm the story
   is shippable — give it the story file, `docs/spec.md`/`docs/plan.md`, the diff text + changed paths,
   the reviewer verdicts, and the gate results. It returns `STATUS: PASS | FAIL | UNKNOWN`. **A story
   may not ship unless STATUS is PASS.** `FAIL` → back to **Fix** (step 4, same ≤3-round bound), then
   re-verify; `UNKNOWN` → obtain the exact missing evidence it names and re-verify, or escalate to the
   user. For non-trivial work, record `docs/verification/<story-id>.md`. See `references/verification.md`.
7. **Ship.** With gates green, no open `block`/`major`, and `pm-verifier` `PASS`, commit **only this
   story's files** to the story branch. **Sync first:** pull/rebase the integration branch; if its
   tip moved after your gates ran, re-gate on the merged result before merging. Then integrate:
   - **Local by default** → check out the integration branch and `--no-ff` merge the story branch
     with a PR-style message.
   - **Remote PR only if the user has explicitly asked for pushes/PRs** *and* `gh auth status`
     succeeds *and* a GitHub remote exists → push the branch, open a PR, and merge it.
   **Never push to a remote without an explicit request** (hard rule).
8. **Log.** Append the story outcome to `pm/log.md` (author-prefixed entry), update
   `pm/actors/<you>.json`, and **remove the story's entry from `assignments`** in
   `pm/pm-state.json` — then **commit this `pm/` state update alongside the ship** (on the
   integration branch, right after the merge), so the pushed repo carries the current resume point
   and the released claim. Never write secrets into `pm/`.
9. **Document (optional — at the sprint/project boundary, not per story).** Once a sprint's stories
   are merged, you may dispatch `technical-writer` to refresh user-facing docs (README, usage,
   CHANGELOG) and, at project end, produce the completion report at `docs/completion-report.md` from
   `${CLAUDE_PLUGIN_ROOT}/templates/completion-report.md.template`. It writes docs only — never
   source. Log that it ran, or that you skipped it.

## Handoff contracts (keep them tight)
- **To the builder — down:** the story file path. **up:** status; files changed; diff summary;
  what it built/tested; follow-ups.
- **To the reviewer — down:** the story file path + the diff **text you generated** (the reviewer
  can't diff). **up:** findings + verdict.
- **To the verifier — down:** the story file + `docs/spec.md`/`docs/plan.md` + the diff text + the
  reviewer verdicts + the gate results. **up:** `STATUS` (PASS/FAIL/UNKNOWN) + per-criterion/gate
  evidence + the action to take.
- **You (the PM):** run the deterministic gates yourself — their result is yours, not taken on a
  subagent's word. Never read raw worker transcripts; only their summaries.

## Scope freeze
Once a story starts, its scope is **frozen**. If new requirements appear, stop and run
`/pm-skill:correct-course`: checkpoint the in-flight work, apply the change at the right altitude
(spec / plan / story), re-sign-off if the change is material, then restart the affected story with
fresh counters. Never drip-feed new asks mid-flight.

## Checkpoints
- **Default: sprint-level.** Run all stories in a sprint, then pause for the user's review at the
  sprint boundary. (Configurable per project to *story-level* — pause before each merge — or
  *fully autonomous*.)
- **Always escalate immediately** for high-risk or large-blast-radius merges, regardless of mode.
- **Offer a handoff at natural stops.** At a sprint checkpoint, before a long pause, or when the
  session's context is running long, offer `/pm-skill:handoff` — a committed
  `pm/actors/<id>.HANDOFF.md` is what lets the next session skip re-discovery. (A bundled
  SessionStart hook re-grounds new and freshly-compacted sessions from `pm/` automatically.)

See `review-gates.md` for the severity model and the definition of done.
