# Implementation Loop

Run each story through this loop. **You orchestrate; you do not write code.** Take only summaries
back — never raw transcripts (protect your context).

## Per-story cycle
1. **Build.** Dispatch `expert-builder` with **only the story file path** (it reads the project
   `CLAUDE.md` itself). It implements and tests the story and returns a structured summary.
2. **Review.** Dispatch `code-integrity-reviewer` with the story file + the diff. It returns
   severity-graded findings (`block`/`major`/`minor`) and a `PASS`/`CONCERNS`/`FAIL` verdict.
3. **Fix.** Send `block`/`major` findings back to `expert-builder`. Re-review after each fix,
   **up to 3 rounds**; if still failing, **escalate to the user**.
4. **External review (optional).** Only if an external reviewer is **explicitly available**: run a
   **local secret-scan first** (don't send code containing secrets out), then an independent
   review, feed findings back, fix. If unavailable, **log that it was skipped** — never silently.
5. **Ship.** Branch per story (`pm/S<sprint>-<n>-<slug>`). **Run the project's gates yourself
   first** (see `review-gates.md`). Then:
   - if `gh auth status` succeeds **and** a GitHub remote exists → open a real PR and merge it;
   - otherwise → local `--no-ff` merge into the integration branch with a PR-style message.
   Never push to a remote without an explicit request.
6. **Log.** Append the story outcome to `tmp/log.md`.

## Handoff contracts (keep them tight)
- **To the builder — down:** the story file path. **up:** status; files changed; diff summary;
  what it built/tested; follow-ups.
- **To the reviewer — down:** the story file path + the diff (or base ref). **up:** findings +
  verdict.
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
