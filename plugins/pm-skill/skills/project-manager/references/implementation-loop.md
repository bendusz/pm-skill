# Implementation Loop

Run each story through this loop. **You orchestrate; you do not write code.** Take only summaries
back — never raw transcripts (protect your context).

The **integration branch** is the project's default branch (e.g. `main`) that the scaffold commit
landed on. You cut every story branch from it and merge each story back into it.

## Per-story cycle
0. **Branch.** Ensure the working tree is **clean** first — if it has unrelated changes, stop and
   ask (see Repository safety). Then, from the integration branch, create and check out the story
   branch `pm/S<sprint>-<n>-<slug>`. All of this story's work happens here.
1. **Build.** Dispatch `expert-builder` with **only the story file path** (it reads the project
   `CLAUDE.md` itself). It edits the working tree (no commits — you own git) and returns a
   structured summary, including the **list of files it changed**. If it returns *blocked* or
   fails, retry up to **2** times with clarification, then escalate to the user.
2. **Gate.** Run the project's deterministic gates yourself (test/lint/build per
   `review-gates.md`; skip any that are `N/A`). If a gate fails, go to Fix (step 4) before review.
3. **Review.** Produce the diff yourself and pass it to the reviewer inline — the reviewer has no
   Bash and cannot diff. Diff **only the story's changed paths** (from the builder's summary), e.g.
   `git add -N -- <changed paths> && git diff -- <changed paths>` — **never `git add -A`** (that
   would sweep in unrelated work). Dispatch `code-integrity-reviewer` with the story file + that
   diff text. It returns severity-graded findings (`block`/`major`/`minor`) and a
   `PASS`/`CONCERNS`/`FAIL` verdict.
4. **Fix.** Send `block`/`major` findings back to `expert-builder`. After each fix, **re-run the
   gates and regenerate the diff for re-review**, **up to 3 rounds**; if still failing, **escalate
   to the user**.
5. **External review (optional).** Only if an external reviewer is **explicitly available**:
   secret-scan the diff first — if no scanner exists, run
   `git grep -nIE '(API|SECRET|TOKEN|PASSWORD|PRIVATE[_-]?KEY)'` over the changed files, and if it
   trips do **not** send code out. Then an independent review → feed findings back → fix. If no
   external reviewer is available, **log that it was skipped** — never silently.
6. **Ship.** With gates green and no open `block`/`major`, commit **only this story's files** to the
   story branch, then integrate into the integration branch:
   - **Local by default** → check out the integration branch and `--no-ff` merge the story branch
     with a PR-style message.
   - **Remote PR only if the user has explicitly asked for pushes/PRs** *and* `gh auth status`
     succeeds *and* a GitHub remote exists → push the branch, open a PR, and merge it.
   **Never push to a remote without an explicit request** (hard rule).
7. **Log.** Append the story outcome to `tmp/log.md`.

## Handoff contracts (keep them tight)
- **To the builder — down:** the story file path. **up:** status; files changed; diff summary;
  what it built/tested; follow-ups.
- **To the reviewer — down:** the story file path + the diff **text you generated** (the reviewer
  can't diff). **up:** findings + verdict.
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
