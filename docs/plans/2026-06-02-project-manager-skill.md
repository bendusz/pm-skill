# Project Manager Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a generic, public, self-contained Claude Code plugin (`pm-skill`) whose `project-manager` skill makes Claude act as a Project/Product Manager that discovers, plans, gets sign-off, decomposes into stories, and orchestrates build/review/fix/ship via subagents — without writing code itself.

**Architecture:** A single-repo marketplace + plugin. A lean router `SKILL.md` (loaded on trigger) points to per-phase `references/*.md` (loaded on demand). Two bundled agents (`expert-builder`, `code-integrity-reviewer`) do the work; a thin `/pm-skill:pm` command is an explicit entry. Manifests make it installable via `/plugin marketplace add`.

**Tech Stack:** Markdown (skill + references + agents + docs), JSON (`plugin.json`, `marketplace.json`), YAML frontmatter. Verification via `jq`, `grep`, `claude plugin validate`, and a subagent dry-run. No runtime language/build.

**Source of truth for content:** the approved spec `docs/specs/2026-06-02-project-manager-skill-design.md`. This plan sequences the build and pins verification; it does not restate the spec (DRY). Where a file's exact bytes matter (manifests, frontmatter, core skill/agents, templates) the full content is given below.

---

## How to read this plan

- **This is a docs/config artifact.** Each task's "test" is a real, runnable check (JSON validity, frontmatter fields, required sections, `claude plugin validate`, link resolution) — not unit tests. The final task is a behavioral dry-run of the workflow.
- **Phasing (per the spec's "full spine, phased build" decision):**
  - **Phase A — Installable skeleton:** manifests + `SKILL.md` + both agents + command → the plugin installs and validates.
  - **Phase B — Workflow brains:** the six `references/*.md` → the loop is fully specified.
  - **Phase C — Templates** the skill writes into target projects.
  - **Phase D — Docs, release, and the behavioral dry-run gate.**
- **Execute on a branch** (e.g. `build/pm-skill-v1`); the execution sub-skill sets this up. Generic-artifact rule: nothing under `plugins/pm-skill/**` may name a specific third-party plugin (superpowers, Codex, etc.) — those appear only as examples in `README.md`.
- **`jq` assumption:** `jq` is available. If not, the executor installs it or substitutes `python3 -m json.tool`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `.claude-plugin/marketplace.json` | Marketplace manifest; lists the one plugin at `./plugins/pm-skill`. |
| `plugins/pm-skill/.claude-plugin/plugin.json` | Plugin manifest (name, version, license, etc.). |
| `plugins/pm-skill/skills/project-manager/SKILL.md` | Lean router: persona, hard rules, phase map, env detection, resume. |
| `plugins/pm-skill/skills/project-manager/references/discovery.md` | Phase 0 procedure. |
| `…/references/planning-and-signoff.md` | Phase 1 procedure (plan + sign-off + scaffold). |
| `…/references/decomposition.md` | Phase 2 procedure (sprints + story files). |
| `…/references/implementation-loop.md` | Phase 3 procedure (per-story loop + handoff contracts). |
| `…/references/review-gates.md` | Phase 4 procedure (severity, gates, done). |
| `…/references/logging-and-state.md` | Phase 5 procedure (`tmp/log.md` + resume). |
| `plugins/pm-skill/agents/expert-builder.md` | Implementation subagent. |
| `plugins/pm-skill/agents/code-integrity-reviewer.md` | Read-only review subagent. |
| `plugins/pm-skill/commands/pm.md` | Thin explicit entry → the skill. |
| `plugins/pm-skill/templates/{CLAUDE.md,plan.md,story.md,log.md}.template` | Files the skill writes into target projects. |
| `README.md`, `LICENSE`, `CHANGELOG.md` | Public repo docs. |
| `docs/prior-art.md` | Cited research provenance. |

---

## Phase A — Installable skeleton

### Task 1: Manifests (marketplace + plugin)

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/pm-skill/.claude-plugin/plugin.json`

- [ ] **Step 1: Write the verification check first, run it (expect fail)**

Run: `jq empty .claude-plugin/marketplace.json plugins/pm-skill/.claude-plugin/plugin.json && echo OK`
Expected: FAIL (files do not exist yet).

- [ ] **Step 2: Create `.claude-plugin/marketplace.json`**

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "pm-skill",
  "description": "A Project/Product Manager skill that orchestrates software delivery through subagents.",
  "owner": { "name": "REPLACE_OWNER", "url": "https://github.com/REPLACE_OWNER" },
  "plugins": [
    {
      "name": "pm-skill",
      "source": "./plugins/pm-skill",
      "description": "Claude acts as a PM: discover, plan, get sign-off, decompose, and orchestrate build/review/ship via agents.",
      "version": "0.1.0",
      "category": "workflow",
      "homepage": "https://github.com/REPLACE_OWNER/pm-skill",
      "tags": ["skill", "project-management", "orchestration", "agents", "workflow"]
    }
  ]
}
```

- [ ] **Step 3: Create `plugins/pm-skill/.claude-plugin/plugin.json`**

```json
{
  "name": "pm-skill",
  "description": "Claude acts as a Project/Product Manager: discover, plan, get sign-off, decompose into stories, and orchestrate build/review/fix/ship via subagents — without writing the code itself.",
  "version": "0.1.0",
  "author": { "name": "REPLACE_OWNER", "url": "https://github.com/REPLACE_OWNER" },
  "homepage": "https://github.com/REPLACE_OWNER/pm-skill",
  "repository": "https://github.com/REPLACE_OWNER/pm-skill",
  "license": "MIT",
  "keywords": ["claude-code", "plugin", "skill", "project-manager", "orchestration", "agents"]
}
```

- [ ] **Step 4: Run verification (expect pass)**

Run: `jq empty .claude-plugin/marketplace.json plugins/pm-skill/.claude-plugin/plugin.json && jq -r '.plugins[0].source' .claude-plugin/marketplace.json`
Expected: PASS, prints `./plugins/pm-skill`.

> Note: replace `REPLACE_OWNER` with the real GitHub owner before release (Task 15 covers final values). Leaving it now is acceptable; it is flagged again in the release task.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/pm-skill/.claude-plugin/plugin.json
git commit -m "feat: add marketplace and plugin manifests"
```

---

### Task 2: Router `SKILL.md`

**Files:**
- Create: `plugins/pm-skill/skills/project-manager/SKILL.md`

- [ ] **Step 1: Create the file with this exact content**

```markdown
---
name: project-manager
description: Use when the user wants to plan, manage, or deliver a software project or feature end to end — discovery, requirements, a PRD or delivery plan, scope, milestones, a roadmap, sprint or story/task breakdown, or orchestrating implementation. Acts as a Project/Product Manager that discovers, plans, gets sign-off, decomposes into stories, and orchestrates build/review/fix/ship through subagents without writing the code itself.
---

# Project Manager

You are a **Project / Product Manager**. You work *with* the user — the customer-facing
manager who represents an end **customer** — to discover the best solution, agree a plan,
get explicit sign-off, then **orchestrate** delivery through specialist subagents. You
produce plans and coordinate agents; you do **not** write implementation code yourself.

## Hard rules (non-negotiable)
1. **PM, not coder.** Never write implementation code. Orchestrate via subagents.
2. **Protect your context.** Give each subagent only the minimal context it needs (in the
   build loop, just the story file). Take back only a structured summary — never raw
   transcripts. Delegate heavy reading/research to read-only subagents.
3. **No implementation before explicit human sign-off** on the plan.
4. **Always log.** Append to `tmp/log.md` after every meaningful step.
5. **Separate reviewer.** The agent that reviews is never the agent that built.
6. **Deterministic gates.** Whatever of test/lint/build the project actually has must pass —
   you run them yourself, not on a subagent's word.
7. **Bounded loops.** Cap the fix and re-review loop at 3 rounds and builder retries at 2,
   then escalate to the user.
8. **Repository safety.** Never overwrite an existing file without showing a diff and asking;
   commit only files you created or changed for the current story; `git init` only in a
   non-repo and only after asking; never push without an explicit request.

## Workflow — load only the reference for the active phase
0. **Discovery** → `references/discovery.md` — understand the need; resolve `[NEEDS CLARIFICATION]`.
1. **Plan and sign-off** → `references/planning-and-signoff.md` — write `docs/plan.md`; get approval; scaffold.
2. **Decomposition** → `references/decomposition.md` — sprints and self-contained story files.
3. **Implementation loop** → `references/implementation-loop.md` — per story: build → review → fix → (optional external review) → ship → log.
4. **Review gates** → `references/review-gates.md` — severity model, deterministic gates, done definition.
5. **Logging and state** → `references/logging-and-state.md` — `tmp/log.md` format and resume.

Read only the reference for the phase you are in. Do not preload them all.

## Environment — detect and adapt, never depend
On a bare install everything below still works.
- `git` — version control. Offer to init if absent and the user wants it.
- `gh` + a GitHub remote — only then open real PRs; otherwise use local merges.
- If a more specialized tool or skill exists for a step (a dedicated planner, an external
  reviewer), you MAY prefer it — but your bundled agents and these references are always
  sufficient on their own.

## Agents you orchestrate
- `expert-builder` — implements one story end to end (code + tests).
- `code-integrity-reviewer` — read-only review of a story's diff for correctness and security.
- For read-only research, dispatch the built-in `general-purpose` (or `Explore`) agent.

## On resume
If `tmp/log.md` exists, read it first to recover the objective, current sprint/story, branch
state, and next step — then continue from there.
```

- [ ] **Step 2: Verify frontmatter and size**

Run: `head -3 plugins/pm-skill/skills/project-manager/SKILL.md | grep -E '^(name|description):' | wc -l; wc -l < plugins/pm-skill/skills/project-manager/SKILL.md`
Expected: first number `2` (name + description present); second number well under `500`.

- [ ] **Step 3: Verify no third-party plugin names leaked**

Run: `grep -iE 'superpowers|codex|skill-codex' plugins/pm-skill/skills/project-manager/SKILL.md || echo CLEAN`
Expected: `CLEAN`.

- [ ] **Step 4: Commit**

```bash
git add plugins/pm-skill/skills/project-manager/SKILL.md
git commit -m "feat: add project-manager router SKILL.md"
```

---

### Task 3: Agent `expert-builder`

**Files:**
- Create: `plugins/pm-skill/agents/expert-builder.md`

- [ ] **Step 1: Create the file with this exact content**

```markdown
---
name: expert-builder
description: Use this agent to implement a single, well-scoped story from a story file. It writes the code and tests for exactly that story, follows the project's CLAUDE.md, and returns a structured summary. <example>The PM has docs/stories/S1-2-auth.md and dispatches expert-builder with that story path to implement it.</example>
tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
color: blue
---

You are a senior implementation engineer. You are given exactly ONE story to implement.

## Inputs
- A path to a story file — read it first. It has the goal, self-contained context, acceptance
  criteria, out-of-scope, and a verification command.
- The project `CLAUDE.md` — read it for stack, commands, conventions, and workflow rules.

## How you work
- Implement ONLY what the story specifies. Do not expand scope. If the story is wrong or
  under-specified, stop and report it rather than guessing.
- Follow the project's conventions and the rules in `CLAUDE.md`.
- Write tests for the behavior using the project's test framework; prefer test-first where practical.
- Run the story's verification command and the project's tests locally to check your work.
- Make no commits, branches, PRs, or merges — the PM owns git.

## Return — a structured summary only
- **Status:** done / blocked (+ why)
- **Files changed:** paths created/modified
- **Diff summary:** 2–5 bullets on what changed
- **Tests:** what you added and the result of running them
- **Follow-ups / risks:** anything the PM should know
Do not paste full file contents or raw logs.
```

- [ ] **Step 2: Verify frontmatter fields**

Run: `grep -E '^(name|description|tools|model|color):' plugins/pm-skill/agents/expert-builder.md`
Expected: all five lines present; `tools:` includes `Write` and `Edit`.

- [ ] **Step 3: Commit**

```bash
git add plugins/pm-skill/agents/expert-builder.md
git commit -m "feat: add expert-builder agent"
```

---

### Task 4: Agent `code-integrity-reviewer`

**Files:**
- Create: `plugins/pm-skill/agents/code-integrity-reviewer.md`

- [ ] **Step 1: Create the file with this exact content**

```markdown
---
name: code-integrity-reviewer
description: Use this agent to review a single story's diff for correctness, security, and convention adherence. It is read-only and returns severity-graded findings plus a verdict. <example>After expert-builder finishes a story, the PM dispatches code-integrity-reviewer with the story file and the diff to review it.</example>
tools: Read, Grep, Glob
model: inherit
color: red
---

You are a meticulous code reviewer focused on integrity and security. You are read-only:
you have no Write, Edit, or Bash tools and must not attempt to change anything.

## Inputs
- The story file (acceptance criteria and intended scope).
- The diff for that story, or a base ref to compare against.
- The project `CLAUDE.md` for conventions.

## What to check
- **Correctness:** does the change meet the acceptance criteria? Logic errors, edge cases,
  broken contracts.
- **Security:** injection, auth, secret handling, unsafe deserialization, path traversal, etc.
- **Integrity and conventions:** error handling, naming, CLAUDE.md adherence, dead or
  duplicated code, missing tests.

## Return — structured
For each finding: `severity` (block | major | minor), `file:line`, the problem, and a concise
suggested fix.
End with a verdict: `PASS` (no block/major), `CONCERNS` (only minor), or `FAIL` (one or more
block/major).
Do not run tests or modify files — the PM runs the deterministic gates.
```

- [ ] **Step 2: Verify it is genuinely read-only**

Run: `grep -E '^tools:' plugins/pm-skill/agents/code-integrity-reviewer.md`
Expected: exactly `tools: Read, Grep, Glob` (no `Write`, `Edit`, or `Bash`).

- [ ] **Step 3: Commit**

```bash
git add plugins/pm-skill/agents/code-integrity-reviewer.md
git commit -m "feat: add read-only code-integrity-reviewer agent"
```

---

### Task 5: Command `/pm-skill:pm`

**Files:**
- Create: `plugins/pm-skill/commands/pm.md`

- [ ] **Step 1: Create the file with this exact content**

```markdown
---
description: Act as the Project/Product Manager — discover, plan, get sign-off, and orchestrate delivery.
---

Use the `project-manager` skill to act as the Project/Product Manager for the request below.
If no request is given, begin with discovery.

Request: $ARGUMENTS
```

- [ ] **Step 2: Verify**

Run: `test -f plugins/pm-skill/commands/pm.md && grep -q 'project-manager' plugins/pm-skill/commands/pm.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add plugins/pm-skill/commands/pm.md
git commit -m "feat: add /pm-skill:pm command entry"
```

---

### Task 6: Validate the skeleton installs

**Files:** none (validation only).

- [ ] **Step 1: Validate the plugin**

Run: `claude plugin validate ./plugins/pm-skill` *(if this subcommand/flag differs in the installed CLI, fall back to Step 2; record the working command in `docs/prior-art.md`.)*
Expected: validation passes (manifests + skill + agents + command recognized).

- [ ] **Step 2: Structural fallback check**

Run:
```bash
for f in .claude-plugin/marketplace.json plugins/pm-skill/.claude-plugin/plugin.json; do jq empty "$f" || echo "BAD $f"; done
test -f plugins/pm-skill/skills/project-manager/SKILL.md \
 && test -f plugins/pm-skill/agents/expert-builder.md \
 && test -f plugins/pm-skill/agents/code-integrity-reviewer.md \
 && test -f plugins/pm-skill/commands/pm.md && echo STRUCTURE_OK
```
Expected: no `BAD` lines; prints `STRUCTURE_OK`.

- [ ] **Step 3: Commit (if validate surfaced fixes)**

```bash
git add -A && git commit -m "fix: address plugin validation findings" || echo "nothing to commit"
```

---

## Phase B — Workflow brains (`references/*.md`)

Each reference file is a self-contained, generic procedure. **Content source:** the matching
spec section. Each task: write the file to satisfy the contract, verify required section
headings exist, verify no third-party plugin names, commit. Files over 100 lines must open
with a table of contents.

Common acceptance check (substitute `<file>` and the expected headings):
```bash
grep -c '^## ' <file>                                   # sections present
grep -iE 'superpowers|codex|skill-codex' <file> || echo CLEAN   # must print CLEAN
```

### Task 7: `references/discovery.md`  (spec §7 Phase 0)
**Files:** Create `plugins/pm-skill/skills/project-manager/references/discovery.md`
- [ ] **Step 1:** Write it. Required content:
  - Goal: collaborate with the user to understand the customer's need and agree the best solution.
  - Procedure: conversational, one question at a time; surface 2–3 options with a recommendation.
  - Mark unknowns inline as `[NEEDS CLARIFICATION: …]`; **exit gate:** none remain before planning.
  - Context protection: dispatch the built-in `general-purpose`/`Explore` agent for read-only research; decisions stay with the user.
  - Output: a shared problem statement + chosen direction, logged to `tmp/log.md`.
- [ ] **Step 2:** Run the common acceptance check. Expected: ≥4 sections; `CLEAN`.
- [ ] **Step 3:** Commit — `git add -A && git commit -m "feat: add discovery phase reference"`

### Task 8: `references/planning-and-signoff.md`  (spec §7 Phase 1, §10.1)
**Files:** Create the file.
- [ ] **Step 1:** Write it. Required content:
  - Produce `docs/plan.md` with the §10.1 section list (incl. a **Commands** section recording the project's real test/lint/build/run commands or `N/A`, and a **Clarifications** section that must be empty).
  - **Sign-off gate:** present the plan; iterate to an unambiguous human "approved"; record approver + date in `docs/plan.md` and `tmp/log.md`. Procedural gate — state plainly it is not hook-enforced in v1.
  - **Scaffold after sign-off**, observing Repository safety: `git init` only if absent and after asking; generate project `CLAUDE.md` (per template) without overwriting an existing one (diff + ask); `.gitignore` includes `tmp/`; commit only skill-created files.
- [ ] **Step 2:** Acceptance check + confirm it contains the literal strings `docs/plan.md` and `tmp/log.md`. `CLEAN`.
- [ ] **Step 3:** Commit — `git commit -am "feat: add planning-and-signoff phase reference"`

### Task 9: `references/decomposition.md`  (spec §7 Phase 2, §10.2)
**Files:** Create the file.
- [ ] **Step 1:** Write it. Required content:
  - Break the approved plan into sprints (each independently valuable) → self-contained story files under `docs/stories/` using the §10.2 format.
  - Each story embeds architecture context + testable acceptance criteria + a verification command, so a worker needs only its story file + `CLAUDE.md`.
  - Order by dependency; tag independent stories `[P]` (metadata only; sequential execution in v1).
  - Present the sprint/story map to the user (visible, not a hard gate).
- [ ] **Step 2:** Acceptance check; confirm it references `docs/stories/`. `CLEAN`.
- [ ] **Step 3:** Commit — `git commit -am "feat: add decomposition phase reference"`

### Task 10: `references/implementation-loop.md`  (spec §7 Phase 3)
**Files:** Create the file.
- [ ] **Step 1:** Write it. Required content:
  - The per-story 6-step cycle: build (`expert-builder`, story file only) → review (`code-integrity-reviewer` on the diff) → fix (re-review each fix, up to 3 rounds, then escalate) → optional external review (only if explicitly available; local secret-scan first; log if skipped) → ship → log.
  - **Ship rules:** branch per story; open a real PR + merge via `gh` only if `gh auth status` succeeds AND a GitHub remote exists; else local `--no-ff` merge with a PR-style message. PM runs the gates first.
  - **Per-agent handoff contracts** (builder vs reviewer vs PM-owned gates) exactly as spec §7 Phase 3.
  - **Scope freeze** once a story starts; changes go through a `correct-course` step.
  - **Checkpoint:** default sprint-level (configurable: story-level / autonomous); escalate risky/large-blast-radius merges regardless.
- [ ] **Step 2:** Acceptance check; confirm it contains `gh auth status` and `correct-course`. `CLEAN`.
- [ ] **Step 3:** Commit — `git commit -am "feat: add implementation-loop phase reference"`

### Task 11: `references/review-gates.md`  (spec §7 Phase 4)
**Files:** Create the file.
- [ ] **Step 1:** Write it. Required content:
  - Reviewer is a separate agent; severity `block`/`major`/`minor` (only block/major force a fix); verdict `PASS`/`CONCERNS`/`FAIL`.
  - Deterministic gates = the project's actual discovered commands (or `N/A`); the PM runs them after the build and after each fix.
  - **Done** definition: acceptance criteria met; no open block/major; all non-`N/A` gates green; logged.
  - Escalation after 3 failed fix/verify iterations.
- [ ] **Step 2:** Acceptance check; confirm it contains `PASS`, `CONCERNS`, `FAIL`. `CLEAN`.
- [ ] **Step 3:** Commit — `git commit -am "feat: add review-gates phase reference"`

### Task 12: `references/logging-and-state.md`  (spec §7 Phase 5, §10.4)
**Files:** Create the file.
- [ ] **Step 1:** Write it. Required content:
  - `tmp/log.md` (gitignored) is the runtime logbook + recovery state, in the §10.4 format (Current State header + append-only timestamped bullets, written for a colleague with zero context).
  - Committed planning artifacts (`docs/plan.md`, `docs/stories/*`) are the source of truth; `tmp/` is disposable.
  - Resume procedure: read `tmp/log.md` first; reconstruct objective/sprint/story/branch/next.
- [ ] **Step 2:** Acceptance check; confirm it contains `tmp/log.md` and `Current State`. `CLEAN`.
- [ ] **Step 3:** Commit — `git commit -am "feat: add logging-and-state phase reference"`

---

## Phase C — Templates

### Task 13: Target-project templates

**Files:** Create under `plugins/pm-skill/templates/`:
- `CLAUDE.md.template`, `plan.md.template`, `story.md.template`, `log.md.template`

- [ ] **Step 1: `story.md.template`** — exact content (spec §10.2):

```markdown
# S<sprint>-<n> — <title>
Sprint: <n> · Priority: <high|med|low> · Depends on: <ids|none> · Parallel-safe: <yes|no>

## Goal
<one paragraph>

## Context (self-contained)
<architecture, files, interfaces, conventions the builder needs — so it need not read the whole repo>

## Acceptance criteria (testable)
- [ ] <criterion>

## Out of scope
- <item>

## Verification
- Prove done with: `<command>`
```

- [ ] **Step 2: `log.md.template`** — exact content (spec §10.4):

```markdown
# PM Log — <project>

## Current State
- Objective: <one line>
- Plan: docs/plan.md — APPROVED by <name> on <date>
- Sprint: <n> of <N> — "<goal>"
- Story: <id> "<title>" — <status>
- Branch: <branch> (clean | N uncommitted)
- Next: <continuation point>

## Log
- <YYYY-MM-DD HH:MM> — <2–3 sentence summary>
```

- [ ] **Step 3: `plan.md.template`** — headings from spec §10.1 (Overview, Goals, Target users, Scope In/Out, Stories table `| id | title | priority | acceptance | depends-on | [P] |`, Architecture, Non-functional requirements, Commands (test/lint/build/run or `N/A`), Risks, Clarifications (must be empty), Sign-off `Approved by … on YYYY-MM-DD`).

- [ ] **Step 4: `CLAUDE.md.template`** — under 150 lines, non-negotiables first (spec §10.3): a **Workflow rules** block ("Never implement before the human approves the plan. The PM orchestrates and does not code. Log progress to `tmp/log.md`. The project's gates (test/lint/build) must pass before a story is done."), then Project purpose, Commands, Architecture/layout, Conventions, Gotchas — each as a placeholder line the skill fills in.

- [ ] **Step 5: Verify** — `ls plugins/pm-skill/templates/*.template | wc -l` → `4`; `grep -q 'Current State' plugins/pm-skill/templates/log.md.template && echo OK` → `OK`.

- [ ] **Step 6: Commit** — `git add plugins/pm-skill/templates && git commit -m "feat: add target-project templates"`

---

## Phase D — Docs, release, dry-run

### Task 14: `README.md`

**Files:** Create `README.md`.

- [ ] **Step 1:** Write it with these sections:
  - **What it is** (1 paragraph) and the workflow line `discover → align → plan → sign-off → decompose → orchestrate → review → ship → log`.
  - **Install:** `/plugin marketplace add REPLACE_OWNER/pm-skill` then `/plugin install pm-skill`.
  - **Usage:** intent-trigger ("act as my PM to build X") or `/pm-skill:pm <request>`.
  - **How it works:** the phases + the two bundled agents + the `tmp/log.md` recovery log.
  - **Optional enhancements (works alongside, not required):** a short list naming example external tools (e.g. a dedicated planning/TDD skill suite; an external code-review CLI such as a Codex-based reviewer; `gh` for real PRs) — clearly marked optional.
  - **Safety:** sign-off gate + repository-safety summary.
- [ ] **Step 2:** Verify — `grep -qiE 'optional enhancements' README.md && grep -q '/pm-skill:pm' README.md && echo OK` → `OK`. (README is the ONE place third-party tools may be named.)
- [ ] **Step 3:** Commit — `git add README.md && git commit -m "docs: add README"`

### Task 15: `LICENSE`, `CHANGELOG.md`, `docs/prior-art.md`, finalize owner

**Files:** Create `LICENSE`, `CHANGELOG.md`, `docs/prior-art.md`; edit manifests + README to set the real owner.

- [ ] **Step 1:** `LICENSE` — standard MIT text, year 2026, copyright holder = real owner.
- [ ] **Step 2:** `CHANGELOG.md` — a `## 0.1.0 — 2026-06-02` entry summarizing the initial release (the spine + bundled agents).
- [ ] **Step 3:** `docs/prior-art.md` — the cited reference systems from §15 with one line + URL each: Anthropic Building Effective Agents, Anthropic Multi-Agent Research System, Anthropic skills/plugins/memory docs, ccpm, BMAD-Method, GitHub Spec Kit, Roo Code Boomerang, Task Master AI, superpowers, deanpeters/Product-Manager-Skills. Note which influenced which decision.
- [ ] **Step 4:** Replace every `REPLACE_OWNER` with the real owner.

  Run: `grep -rn 'REPLACE_OWNER' . --include='*.json' --include='*.md' || echo NONE_LEFT`
  Expected: `NONE_LEFT`.
- [ ] **Step 5:** Commit — `git add -A && git commit -m "docs: add LICENSE, CHANGELOG, prior-art; set owner"`

### Task 16: Behavioral dry-run gate

**Files:** none (verification + any fixes the dry-run surfaces).

- [ ] **Step 1: Re-validate** — re-run Task 6 Step 1/2. Expected: passes.

- [ ] **Step 2: Dry-run the workflow via a subagent.** Dispatch a `general-purpose` subagent with this brief: "In a fresh temp directory, role-play following ONLY the files under `plugins/pm-skill/` as if the plugin were installed. Take this throwaway request: *a CLI that adds two numbers*. Walk Phase 0→1 to a written `docs/plan.md` and STOP at the sign-off gate; then simulate ONE story through the implementation-loop reference using local git (no remote). Report, per phase: was the reference file self-sufficient? any ambiguity, dead-end, or contradiction? did the loop's handoff contracts and gates make sense?"

- [ ] **Step 3: Triage findings.** For each issue the dry-run reports, fix the relevant reference/agent file. Re-run the dry-run if a `block`-level gap was found.
  Expected: the subagent completes all phases and reports no `block`-level gaps.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "test: behavioral dry-run; fix reference gaps"`

- [ ] **Step 5: Finish the branch** — use superpowers:finishing-a-development-branch to merge `build/pm-skill-v1` and decide on a release tag (`v0.1.0`).

---

## Self-Review (run against the spec)

**1. Spec coverage:**
- §4 hard rules → SKILL.md (Task 2). §5 architecture/manifests → Tasks 1–5. §6 router → Task 2.
- §7 phases 0–5 → Tasks 7–12. §8 agents → Tasks 3–4. §9 optional integrations → SKILL.md env block + README (Tasks 2, 14).
- §10 formats → templates (Task 13) + referenced inside Tasks 8–12. §11 checkpoints, §12 error handling → encoded in implementation-loop/review-gates (Tasks 10–11).
- §13 testing/release → Tasks 6, 15, 16. §15 prior art → Task 15. §16 decisions → reflected throughout.
- No spec section is left without a task. ✅

**2. Placeholder scan:** `REPLACE_OWNER` is intentional and gated to zero in Task 15 Step 4. Reference-file tasks carry concrete content contracts (sections + rules + spec pointers), not vague TODOs. ✅

**3. Type/name consistency:** file paths, agent names (`expert-builder`, `code-integrity-reviewer`), command (`/pm-skill:pm`), and artifact paths (`docs/plan.md`, `docs/stories/`, `tmp/log.md`) match the spec and each other across tasks. ✅

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-06-02-project-manager-skill.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. (Fitting: it's the very pattern this plugin encodes.)
2. **Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
