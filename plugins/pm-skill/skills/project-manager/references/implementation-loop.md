# Implementation Loop

Run each story through this loop. **You orchestrate; you do not write code.** Take only summaries
back — never raw transcripts (protect your context).

The **integration branch** is the project's default branch (e.g. `main`) that the scaffold commit
landed on. You cut every story branch from it and merge each story back into it.

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
   safety). Then, from the integration branch, create and check out the story branch
   `pm/S<sprint>-<n>-<slug>`. All of this story's work happens here.
1. **Build.** *(Optional, for clear acceptance criteria: first dispatch `test-engineer` to write the
   acceptance tests — TDD red. Then tell the builder those tests already exist: it must make them
   pass and add only *further* coverage, not rewrite them.)* Dispatch `expert-builder`
   with **only the story file path** (it reads the project `CLAUDE.md` itself). It edits the working
   tree (no commits — you own git) and returns a structured summary, including the **list of files it
   changed**. If it returns *blocked* or fails, retry up to **2** times with clarification, then
   escalate to the user.
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
   and regenerate the diff for re-review**, **up to 3 rounds**; if still failing, **escalate to the
   user**.
5. **External review (optional).** Only if an external reviewer is **explicitly available**:
   secret-scan the diff first — if no scanner exists, run
   `git grep -nIE '(API|SECRET|TOKEN|PASSWORD|PRIVATE[_-]?KEY)'` over the changed files, and if it
   trips do **not** send code out. Then an independent review → feed findings back → fix. If no
   external reviewer is available, **log that it was skipped** — never silently.
6. **Verify.** Before shipping, dispatch `pm-verifier` (read-only) to independently confirm the story
   is shippable — give it the story file, `docs/spec.md`/`docs/plan.md`, the diff text + changed paths,
   the reviewer verdicts, and the gate results. It returns `STATUS: PASS | FAIL | UNKNOWN`. **A story
   may not ship unless STATUS is PASS.** `FAIL` → back to **Fix** (step 4, same ≤3-round bound), then
   re-verify; `UNKNOWN` → obtain the exact missing evidence it names and re-verify, or escalate to the
   user. For non-trivial work, record `docs/verification/<story-id>.md`. See `references/verification.md`.
7. **Ship.** With gates green, no open `block`/`major`, and `pm-verifier` `PASS`, commit **only this
   story's files** to the story branch, then integrate into the integration branch:
   - **Local by default** → check out the integration branch and `--no-ff` merge the story branch
     with a PR-style message.
   - **Remote PR only if the user has explicitly asked for pushes/PRs** *and* `gh auth status`
     succeeds *and* a GitHub remote exists → push the branch, open a PR, and merge it.
   **Never push to a remote without an explicit request** (hard rule).
8. **Log.** Append the story outcome to `tmp/log.md`.
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
Once a story starts, its scope is **frozen**. If new requirements appear, stop and run a
**correct-course** step: revise the story (or the plan) explicitly with the user, then restart the
story. Never drip-feed new asks mid-flight.

## Checkpoints
- **Default: sprint-level.** Run all stories in a sprint, then pause for the user's review at the
  sprint boundary. (Configurable per project to *story-level* — pause before each merge — or
  *fully autonomous*.)
- **Always escalate immediately** for high-risk or large-blast-radius merges, regardless of mode.

See `review-gates.md` for the severity model and the definition of done.
