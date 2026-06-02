# Project Manager Skill — Design Specification

- **Status:** Approved (2026-06-02)
- **Type:** Public, generic Claude Code plugin
- **Working names:** plugin `pm-skill` · skill `project-manager` · command `/pm-skill:pm` (namespaced; all adjustable)

---

## 1. Overview

The **Project Manager Skill** is a generic, self-contained Claude Code plugin that turns
Claude into a disciplined **Project / Product Manager**. The PM collaborates with a human —
the *customer-facing manager* — to discover the right solution for an end *customer*, produce
an **approved** delivery plan, decompose it into sprints and self-contained stories, and then
**orchestrate** implementation through specialist subagents: build → review → fix → merge → log
— **without writing implementation code itself**.

It encodes one repeatable way of working:

> **discover → align → plan → sign-off → decompose → orchestrate → review → ship → log**

It is built to be published publicly and to run on a **bare** Claude Code install, using richer
tools only when they happen to be present.

## 2. Goals and non-goals

### Goals
- Package a repeatable PM/orchestration workflow as a single installable plugin.
- Keep the orchestrator's context small by delegating work and passing only **structured
  summaries** back up.
- A **procedural human sign-off gate** before any implementation (prompt-level in v1; optional
  hook-based hard enforcement is on the roadmap).
- Ship **bundled agents** so the plugin is fully functional with no other plugins installed.
- Stay **generic**: zero dependency on any particular author's environment.

### Non-goals (v1)
- **Deep coupling to any specific platform or plugin** (GitHub Issues, git worktrees, a particular
  external skill/CLI). The plugin stays generic; such tools remain optional, never integrated-in.
- **Roadmap features, explicitly deferred:** per-epic retrospectives, parallel `[P]` *execution*,
  story complexity scoring, cross-artifact consistency analysis, hook-enforced approval gate.

> Note: "the PM does not write code itself" is a core architectural **principle** (§4.1), not a
> non-goal. The delivered system absolutely produces working code — the PM orchestrates it through
> the bundled `expert-builder` agent rather than typing it directly.

## 3. Users and success criteria

- **Primary user:** a developer or lead who wants Claude to *manage delivery* of a project or
  feature, not just write code.
- **Success:** after `/plugin marketplace add <repo>` and install, the user can say *"act as my
  PM to build X"* (or run the namespaced command `/pm-skill:pm`) and receive: discovery → a
  signed-off plan → orchestrated, reviewed, logged implementation. Works on a bare install; richer
  when optional tools exist.

## 4. Design principles (hard rules)

These are stated verbatim in `SKILL.md` and are non-negotiable:

1. **PM, not coder.** Never write implementation code. Orchestrate via subagents.
2. **Protect context.** Pass each subagent only the minimal context it needs — in the build loop,
   just the story file. Take back only a structured summary, never raw transcripts. Delegate heavy
   reading/research to read-only subagents.
3. **No implementation before explicit human sign-off.**
4. **Always log.** Append to `tmp/log.md` after every meaningful step.
5. **Separate reviewer.** The agent that reviews is never the agent that built (avoids
   self-review blind spots).
6. **Deterministic gates.** Whatever of test / lint / build the project actually has (discovered in
   planning) must pass; the PM runs them itself, not on a subagent's word.
7. **Bounded loops.** Cap the fix↔re-review loop at **3** iterations and builder retries at **2**,
   then escalate to the human.
8. **Generic & self-contained.** Bundled defaults are always sufficient. External tools are
   optional, detected generically, and named only in documentation.

## 5. Artifact architecture

Single-repo marketplace + plugin (mirrors the proven public-plugin layout):

```
pm-skill/                                   # repo root = marketplace
├── .claude-plugin/
│   └── marketplace.json                    # lists one plugin, source "./plugins/pm-skill"
├── plugins/pm-skill/                       # the plugin
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/project-manager/
│   │   ├── SKILL.md                        # lean router; body loads on trigger
│   │   └── references/
│   │       ├── discovery.md
│   │       ├── planning-and-signoff.md
│   │       ├── decomposition.md
│   │       ├── implementation-loop.md
│   │       ├── review-gates.md
│   │       └── logging-and-state.md
│   ├── agents/
│   │   ├── expert-builder.md
│   │   └── code-integrity-reviewer.md
│   ├── commands/
│   │   └── pm.md                           # invoked as /pm-skill:pm (plugin commands are namespaced)
│   └── templates/
│       ├── CLAUDE.md.template
│       ├── plan.md.template
│       ├── story.md.template
│       └── log.md.template
├── README.md                               # usage + "Optional enhancements" section
├── LICENSE                                 # MIT
├── CHANGELOG.md
└── docs/
    ├── specs/                              # this document
    └── prior-art.md                        # cited research provenance
```

**Manifests** (fields per current official docs; see `docs/prior-art.md` — confirm with exact,
validated examples during build):
- `marketplace.json` — `name`, `owner` (`name`, optional `email`/`url`), `plugins[]` with `name`
  + `source: "./plugins/pm-skill"` (relative paths must start with `./`; a subdir is the
  documented, safe form — bare `"."` is avoided).
- `plugin.json` — `name` (required) + `version`, `description`, `author`, `homepage`,
  `repository`, `license: MIT`, `keywords`.

**Component rules:** all component dirs (`skills/ agents/ commands/`) live at the **plugin root**,
never inside `.claude-plugin/`. Any in-plugin path reference uses `${CLAUDE_PLUGIN_ROOT}`.

## 6. The router — `SKILL.md` (lean; target < 500 lines)

**Loading semantics:** in a normal session only the skill's `name` + `description` are pre-listed
to Claude; the full `SKILL.md` body loads when the skill is **triggered**, and may need
re-attaching after `/compact`. The description is the trigger surface — nothing may assume the
body is always in context.

**Frontmatter**
- `name: project-manager`
- `description:` third-person, what + **when**, packed with trigger terms so the skill fires
  reliably (it is the *only* part pre-listed). Terms to include: *project plan, roadmap,
  milestones, scope, requirements, PRD, sprint, story/task breakdown, deliver/manage a project or
  feature, orchestrate implementation.* Phrased "Use when the user wants to plan, manage, or
  deliver a project/feature…".
- Invocation: leave model-invocation **on** (so intent can trigger it); also reachable via the
  namespaced command `/pm-skill:pm`. `allowed-tools` left unrestricted (the PM needs Agent, Bash,
  Read, Write, …).

**Body**
1. **Persona** — refined from the approved header (the three-party framing: *customer*, *you /
   customer-facing manager*, *me / PM*).
2. **Hard rules** — §4 verbatim.
3. **Phase map** — one line per phase, each pointing to its `references/` file, loaded only when
   that phase begins.
4. **Capability detection** — generic only: detect `git` and `gh`; state the principle *"your
   bundled agents and procedures are always sufficient; if a more specialized tool or skill is
   available you MAY prefer it, but never depend on one."* No external plugin named here.
5. **On resume** — read `tmp/log.md` first to recover state.

## 7. Workflow phases

Each reference file carries a self-contained, generic procedure (works with no other plugins).
Reference files > 100 lines begin with a table of contents.

### Phase 0 — Discovery (`references/discovery.md`)
- **Goal:** with the user, understand the customer's need and agree the best solution.
- **Behavior:** conversational, one question at a time; surface 2–3 options with a recommendation;
  flag unknowns inline as `[NEEDS CLARIFICATION: …]`. May dispatch the **built-in `general-purpose`
  (or `Explore`) subagent** for read-only research (no bundled agent needed, so this holds on a
  bare install); decisions stay in the PM↔user thread.
- **Exit gate:** all `[NEEDS CLARIFICATION]` resolved before planning. (Rationale: ambiguity is
  the top agent failure mode.)

### Phase 1 — Plan & Sign-off (`references/planning-and-signoff.md`)
- **Output:** `docs/plan.md` (template §10.1) — overview, goals, users, in/out-of-scope, a story
  table with **testable** acceptance criteria + priority, architecture, NFRs, risks. Contains zero
  remaining clarification markers. Also **discover and record the project's actual
  test/lint/build/run commands** (mark any that don't exist as `N/A`).
- **Sign-off gate:** present plan; iterate to an unambiguous human "approved"; record **approver +
  date** in `docs/plan.md` and `tmp/log.md`. No decomposition or code before this. *(Enforced by
  PM discipline in v1; a Stop/PreToolUse hook for hard enforcement is on the roadmap.)*
- **Scaffold (only after sign-off, observing Repository safety below):** `git init` if needed (ask
  first); generate project `CLAUDE.md` (template §10.3, < 150 lines, non-negotiables first);
  `.gitignore` (includes `tmp/`); initial commit of only the skill-created files.

### Phase 2 — Decomposition (`references/decomposition.md`)
- Break the plan into **sprints** (each independently valuable) → **self-contained story files**
  (template §10.2) under `docs/stories/`, each embedding the architecture context, acceptance
  criteria, and a **verification command**, so a worker needs nothing beyond its story file +
  `CLAUDE.md`.
- Order stories by dependency; tag independent ones `[P]` (metadata only in v1; sequential
  execution).
- Present the sprint/story map to the user (visible, but not a hard gate — sign-off already
  covered the plan).

### Phase 3 — Implementation loop (`references/implementation-loop.md`)
Per story, the PM runs (the approved 6-step cycle, with tightened handoff):
1. **Build** — dispatch `expert-builder` with the story file. PM does not code.
2. **Review** — dispatch `code-integrity-reviewer` on the diff → severity-graded findings.
3. **Fix** — feed findings to the builder → fixes; re-review after each fix, up to 3 rounds, then escalate.
4. **External review (optional)** — if a suitable external reviewer is **explicitly available**,
   run an independent pass (local secret-scan first) → feed back → fix. If unavailable, **log that
   it was skipped** (never silently).
5. **Ship** — branch per story; open a real **PR + merge** via `gh` **only if `gh auth status`
   succeeds and a GitHub remote exists**; otherwise a local `--no-ff` merge with a PR-style
   message. The PM independently runs the project's gates (test/lint/build) first.
6. **Log** — append the story outcome to `tmp/log.md`.

- **Handoff contracts (per agent):**
  - *Builder* — **down:** the story file path (it also reads the project `CLAUDE.md`). **up:**
    status, files changed, a diff summary, what it built and tested, follow-ups. It does not own
    the gate verdict.
  - *Reviewer* — **down:** the story file path + the diff (or base ref). **up:** severity-graded
    findings + `PASS`/`CONCERNS`/`FAIL`.
  - *PM* — runs the deterministic gates itself (result is PM-owned, not taken from a subagent) and
    never ingests raw worker transcripts, only these summaries.
- **Scope freeze:** once a story starts, scope is frozen; new requirements go through an explicit
  *correct-course* step (revise the story/plan), never drip-fed mid-flight.
- **Checkpoint (default = sprint-level, configurable):** PM runs all stories in a sprint, then
  pauses for the user's review at the sprint boundary. **Escalate immediately** for high-risk /
  large-blast-radius merges regardless of mode.

### Phase 4 — Review gates (`references/review-gates.md`)
- **Reviewer = separate agent.** Findings are **severity-graded**: `block` / `major` / `minor`.
  Only `block`/`major` force a fix. Verdict per review: `PASS` / `CONCERNS` / `FAIL`.
- **Deterministic gates:** the project's actual test/lint/build commands (discovered in planning
  and recorded in `CLAUDE.md`; any that don't exist are explicitly `N/A`) must pass — the PM runs
  them itself after the build and after each fix. The crisp signal the fix loop needs.
- **"Done" definition for a story:** acceptance criteria met; no open `block`/`major`; all
  non-`N/A` gates green; logged.
- **Escalation:** 3 failed fix/verify iterations on a story → stop and ask the user.

### Phase 5 — Logging & state (`references/logging-and-state.md`)
- `tmp/log.md` (gitignored) is the runtime logbook **and** recovery state (template §10.4):
  a "Current State" header + append-only timestamped bullets, *written for a colleague with zero
  context*.
- **Committed** planning artifacts (`docs/plan.md`, `docs/stories/*`) are the version-controlled
  source of truth; `tmp/` is disposable runtime state.

> **Repository safety (cross-cutting — applies whenever the skill touches files or git):**
> - Before any mutation, check the working tree. If it has **unrelated uncommitted changes**, stop
>   and ask — never absorb the user's in-flight work into a commit.
> - Never overwrite an existing `CLAUDE.md`, `.gitignore`, or other file without showing a diff and
>   getting approval; prefer to **append/merge**.
> - Stage and commit **only** files the skill created or changed for the current story (no
>   `git add -A` over unrelated paths).
> - `git init` only in a non-repo, and only after asking. If git lacks `user.name`/`user.email`,
>   ask before committing.
> - Branch per story off the integration branch; never force-push; never push to a remote without
>   an explicit request.

## 8. Bundled agents

> Invoked as `pm-skill:expert-builder` and `pm-skill:code-integrity-reviewer` (plugin agents are
> namespaced); exact Agent-tool invocation syntax confirmed at install time.

### 8.1 `expert-builder`
- **Frontmatter:** `name: expert-builder`; `description:` "Use this agent to implement a single
  story…" with an embedded `<example>`; `tools:` full implementation set (Read, Write, Edit, Bash,
  Grep, Glob, …); `model: inherit`; `color: blue`.
- **Behavior:** adopt the relevant specialty for the story; implement from the story file + project
  `CLAUDE.md`; write tests; use TDD if available. Stay within the story's scope. Return the
  structured summary in §7-Phase-3's builder contract. Does not open PRs or merge (the PM owns git).

### 8.2 `code-integrity-reviewer`
- **Frontmatter:** `name: code-integrity-reviewer`; `description:` "Use this agent to review a
  story's diff for correctness and security…" with an embedded `<example>`; `tools: Read, Grep,
  Glob` (no Write/Edit/Bash → genuinely cannot modify the repo); `model: inherit`; `color: red`.
- **Behavior:** statically review the diff for correctness bugs, security issues, and convention
  adherence; return severity-graded findings (`file:line` + concise fix suggestion) and a
  `PASS`/`CONCERNS`/`FAIL` verdict. Runs nothing and changes nothing — the **PM** executes the
  deterministic gates (tests/lint/build) itself, per principle §4.6.

> Note: plugin agents cannot use `hooks`, `mcpServers`, or `permissionMode` — none are relied on.

## 9. Optional integrations (generic detection only)

The skill core references **no** external plugin. The README has an *"Optional enhancements —
works nicely alongside, not required"* section listing examples (e.g. a dedicated planning/TDD
skill suite, an external code-review CLI, `gh` for real PRs). Detection uses only **explicit**
signals (a binary on `PATH`, an installed skill); when present the relevant phase may prefer it,
and when an optional integration is skipped the PM **logs that it was skipped** (never silently).
No behavior **depends** on any of them. The optional external review runs a **local secret-scan
first** (a generic pattern grep for keys/tokens, plus any secret-scanner present); if a diff
contains likely secrets the external pass is withheld and flagged.

## 10. Artifact formats

> These artifacts are generated by the skill **in the user's target project** — not in this
> plugin repo. Committed artifacts live under the target project's `docs/` (`docs/plan.md`,
> `docs/stories/`) with the generated `CLAUDE.md` at its root; `tmp/log.md` is gitignored
> runtime state.

### 10.1 `docs/plan.md` (committed)
Sections: Overview · Goals · Target users · Scope (In / Out) · Stories (table: id, title,
priority, acceptance criteria, depends-on, `[P]`) · Architecture · Non-functional requirements ·
Commands (test/lint/build/run, or `N/A`) · Risks · **Clarifications** (must be empty) ·
**Sign-off** (`Approved by … on YYYY-MM-DD`).

### 10.2 Story file `docs/stories/S<sprint>-<n>-<slug>.md` (committed)
```
# S1-2 — <title>
Sprint: 1 · Priority: high · Depends on: S1-1 · Parallel-safe: no

## Goal
<one paragraph>

## Context (self-contained)
<the architecture, files, interfaces, and conventions the builder needs —
 so it need not read the whole repo>

## Acceptance criteria (testable)
- [ ] …

## Out of scope
- …

## Verification
- Prove done with: `<command>`
```

### 10.3 Generated project `CLAUDE.md` (committed; < 150 lines)
Non-negotiables first, then context every subagent needs:
- **Workflow rules / constitution:** "Never implement before the human approves the plan. The PM
  orchestrates and does not code. Log progress to `tmp/log.md`. The project's gates (test/lint/build)
  must pass before a story is done."
- Project purpose (1–2 lines) · build/test/lint/run commands · architecture & layout ·
  conventions · gotchas. (Survives `/compact`; read by every worker.)

### 10.4 `tmp/log.md` (gitignored)
```
# PM Log — <project>

## Current State
- Objective: <one line>
- Plan: docs/plan.md — APPROVED by <name> on <date>
- Sprint: 2 of 4 — "<goal>"
- Story: S2-3 "<title>" — in review
- Branch: pm/S2-3-<slug> (clean | N uncommitted)
- Next: <continuation point>

## Log
- 2026-06-02 14:32 — S2-2 merged. Auth middleware built + reviewed (1 major fixed); tests green. Next: S2-3.
```

## 11. Checkpoints & escalation

- **Default:** sprint-level (configurable per project to *story-level* or *fully autonomous*).
  *(Trade-off accepted: sprint-level merges stories before the user reviews them; mitigated by the
  risk-escalation rule below and by per-story review gates.)*
- **Always escalate:** high-risk or large-blast-radius merges; 3× failure on a story; corrupted
  git state; any remaining ambiguity.

## 12. Error handling

| Situation | Response |
|---|---|
| Subagent fails / no output | Retry up to 2×, or resume with specific feedback; then escalate |
| Review findings remain | Fix → re-review (cap 3) → escalate |
| Tests/lint/build fail | Story is **not** done; loop or escalate |
| No sign-off | Implementation blocked |
| Not a git repo | Offer `git init` (ask first) |
| No GitHub remote, or `gh` unauthenticated | Local `--no-ff` merge with PR-style message |
| Git missing `user.name`/`user.email` | Ask before committing |
| Working tree has unrelated changes | Stop and ask before any commit |
| Lost session | On resume, read `tmp/log.md` and continue |

## 13. Testing & release

- **Validate:** validate the **plugin** (not just the marketplace) and **test-install it locally**
  before release — `claude plugin validate` on the plugin dir plus a local install smoke test
  (exact flags confirmed during build).
- **Dry-run:** drive the full workflow against a tiny throwaway spec via a subagent to confirm each
  reference file is self-sufficient and the loop holds (per skill-testing best practice).
- **Docs:** `README.md` (install, usage, workflow, optional enhancements), `LICENSE` (MIT),
  `CHANGELOG.md`.

## 14. v1 scope vs roadmap

| In v1 | Roadmap (documented, not built) |
|---|---|
| Discovery w/ `[NEEDS CLARIFICATION]` | Per-epic retrospectives |
| Plan + sign-off gate (procedural) | Parallel `[P]` *execution* |
| Self-contained story files | Story complexity scoring |
| Per-story build/review/fix loop | Cross-artifact consistency `/analyze` |
| Bundled builder + reviewer agents | Hook-enforced approval gate |
| Severity gates + deterministic checks | Pluggable external-reviewer adapters |
| `tmp/log.md` recovery; sprint checkpoints | Configurable model-tiering presets |

*v1 ships the full spine; the **implementation** is phased — a working one-story local
build/review/fix slice first, then PR/merge, then optional integrations.*

## 15. Prior art & references

Design validated against (full citations in `docs/prior-art.md`):
- **Anthropic — Building Effective Agents** (orchestrator-workers, evaluator-optimizer patterns).
- **Anthropic — Multi-Agent Research System** (lead orchestrates; subagents compress context).
- **Anthropic — Claude Code skill/plugin authoring & memory docs** (manifests, progressive
  disclosure, `CLAUDE.md` discipline).
- **ccpm** (automazeio), **BMAD-Method**, **GitHub Spec Kit**, **Roo Code (Boomerang)**,
  **Task Master AI**, **superpowers** (obra), **deanpeters/Product-Manager-Skills**.

## 16. Decisions log

- New skill is **fresh & distinct** from the author's existing `/project` command.
- Distribution stance: **generic & self-contained**, with optional tools detected generically and
  named only in docs (not baked in).
- Architecture: **router + progressive disclosure**.
- Default implementation checkpoint: **sprint-level** (configurable); Codex flagged the
  merge-before-review risk, accepted with the risk-escalation mitigation.
- v1 keeps the **full spine**; implementation is **phased** (one-story local slice → PR/merge →
  optional integrations).
- Spec hardened after an independent **Codex (gpt-5.5) audit**: corrected skill-loading semantics,
  namespaced invocation, repository-safety rules, `gh`/GitHub gating, project-specific gate
  discovery, per-agent handoff contracts, and exact loop caps.
