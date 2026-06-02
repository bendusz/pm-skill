# Project Manager Skill — Design Specification

- **Status:** Approved (design) — 2026-06-02
- **Type:** Public, generic Claude Code plugin
- **Working names:** plugin `pm-skill` · skill `project-manager` · command `/pm` (all adjustable)

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
- Enforce an explicit **human sign-off gate** before any implementation.
- Ship **bundled agents** so the plugin is fully functional with no other plugins installed.
- Stay **generic**: zero dependency on any particular author's environment.

### Non-goals (v1)
- The PM never writes implementation code.
- No hard dependency on any external plugin (superpowers, Codex/skill-codex), GitHub Issues, or
  git worktrees.
- Deferred to **roadmap** (documented, not built in v1): per-epic retrospectives, parallel `[P]`
  *execution*, story complexity scoring, cross-artifact consistency analysis, hook-enforced
  approval gate.

## 3. Users and success criteria

- **Primary user:** a developer or lead who wants Claude to *manage delivery* of a project or
  feature, not just write code.
- **Success:** after `/plugin marketplace add <repo>` and install, the user can say *"act as my
  PM to build X"* (or run `/pm`) and receive: discovery → a signed-off plan → orchestrated,
  reviewed, logged implementation. Works on a bare install; richer when optional tools exist.

## 4. Design principles (hard rules)

These are stated verbatim in `SKILL.md` and are non-negotiable:

1. **PM, not coder.** Never write implementation code. Orchestrate via subagents.
2. **Protect context.** Context passed *down* = the single story file. Information *up* = a
   structured summary only. Never read raw worker transcripts. Delegate research to read-only
   subagents.
3. **No implementation before explicit human sign-off.**
4. **Always log.** Append to `tmp/log.md` after every meaningful step.
5. **Separate reviewer.** The agent that reviews is never the agent that built (avoids
   self-review blind spots).
6. **Deterministic gates.** Tests + lint + build must pass; the PM runs them itself, not on a
   subagent's word.
7. **Bounded loops.** Cap fix ↔ re-review at ~3 iterations, then escalate to the human.
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
│   │   ├── SKILL.md                        # lean router; loaded in full on trigger
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
│   │   └── pm.md                           # thin explicit entry → the skill
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

**Manifests** (fields confirmed against current official docs):
- `marketplace.json` — `name`, `owner{name,url}`, `plugins[]` with `name` + `source:
  "./plugins/pm-skill"` (relative paths must start with `./`; a subdir is the documented, safe
  form — bare `"."` is avoided).
- `plugin.json` — `name` (required) + `version`, `description`, `author`, `homepage`,
  `repository`, `license: MIT`, `keywords`.

**Component rules:** all component dirs (`skills/ agents/ commands/`) live at the **plugin root**,
never inside `.claude-plugin/`. Any in-plugin path reference uses `${CLAUDE_PLUGIN_ROOT}`.

## 6. The router — `SKILL.md` (always loaded; target < 500 lines)

**Frontmatter**
- `name: project-manager`
- `description:` third-person, what + **when**, packed with trigger terms so the skill fires
  reliably (it is the *only* thing pre-loaded). Terms to include: *project plan, roadmap,
  milestones, scope, requirements, PRD, sprint, story/task breakdown, deliver/manage a
  project or feature, orchestrate implementation.* Phrased "Use when the user wants to plan,
  manage, or deliver a project/feature…".

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
  flag unknowns inline as `[NEEDS CLARIFICATION: …]`. May dispatch **read-only** research
  subagents (to protect PM context) but decisions stay in the PM↔user thread.
- **Exit gate:** all `[NEEDS CLARIFICATION]` resolved before planning. (Rationale: ambiguity is
  the top agent failure mode.)

### Phase 1 — Plan & Sign-off (`references/planning-and-signoff.md`)
- **Output:** `plan.md` (template §10.1) — overview, goals, users, in/out-of-scope, a story
  table with **testable** acceptance criteria + priority, architecture, NFRs, risks. Contains
  zero remaining clarification markers.
- **Sign-off gate (hard):** present plan; iterate to an unambiguous human "approved"; record
  **approver + date** in `plan.md` and `tmp/log.md`. No decomposition or code before this.
- **Scaffold (only after sign-off):** `git init` if needed; generate project `CLAUDE.md`
  (template §10.3, < 150 lines, non-negotiables first); `.gitignore` (includes `tmp/`); initial
  commit.

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
1. **Build** — dispatch `expert-builder` with *only* the story file. PM does not code.
2. **Review** — dispatch `code-integrity-reviewer` on the diff → severity-graded findings.
3. **Fix** — feed findings to the builder → fixes. (Loop 2–3 with the reviewer; then escalate.)
4. **External review (optional)** — if a suitable external reviewer is available, run an
   independent pass (secret-scan first) → feed back → fix. Skipped silently if none.
5. **Ship** — branch per story; **PR + merge** via `gh` if a remote exists, else local
   `--no-ff` merge with a PR-style message. PM independently runs tests + lint + build first.
6. **Log** — append the story outcome to `tmp/log.md`.

- **Handoff contract:** down = story file; up = structured summary (status; files changed; diff
  summary; tests/lint/build result; findings; follow-ups). PM never ingests raw transcripts.
- **Scope freeze:** once a story starts, scope is frozen; new requirements go through an explicit
  *correct-course* step (revise the story/plan), never drip-fed mid-flight.
- **Checkpoint (default = sprint-level, configurable):** PM runs all stories in a sprint, then
  pauses for the user's review at the sprint boundary. **Escalate immediately** for high-risk /
  large-blast-radius merges regardless of mode.

### Phase 4 — Review gates (`references/review-gates.md`)
- **Reviewer = separate agent.** Findings are **severity-graded**: `block` / `major` / `minor`.
  Only `block`/`major` force a fix. Verdict per review: `PASS` / `CONCERNS` / `FAIL`.
- **Deterministic gates:** tests + lint + build must pass (PM runs them) — the crisp signal the
  fix loop needs.
- **"Done" definition for a story:** acceptance criteria met; no open `block`/`major`; tests +
  lint + build green; logged.
- **Escalation:** 3 failed fix/verify iterations on a story → stop and ask the user.

### Phase 5 — Logging & state (`references/logging-and-state.md`)
- `tmp/log.md` (gitignored) is the runtime logbook **and** recovery state (template §10.4):
  a "Current State" header + append-only timestamped bullets, *written for a colleague with zero
  context*.
- **Committed** planning artifacts (`plan.md`, `docs/stories/*`) are the version-controlled
  source of truth; `tmp/` is disposable runtime state.

## 8. Bundled agents

### 8.1 `expert-builder`
- **Frontmatter:** `name: expert-builder`; `description:` "Use this agent to implement a single
  story…" with an embedded `<example>`; `tools:` full implementation set (Read, Write, Edit,
  Bash, Grep, Glob, …); `model: inherit`; `color: blue`.
- **Behavior:** adopt the relevant specialty for the story; implement from the story file +
  project `CLAUDE.md`; write tests; use TDD if available. Stay within the story's scope. Return
  the structured summary in §7-Phase-3's contract. Does not open PRs or merge (the PM owns git).

### 8.2 `code-integrity-reviewer`
- **Frontmatter:** `name: code-integrity-reviewer`; `description:` "Use this agent to review a
  story's diff for correctness and security…" with an embedded `<example>`; `tools: Read, Grep,
  Glob, Bash` (read-only — runs tests, never edits); `model: inherit`; `color: red`.
- **Behavior:** review the diff for correctness bugs, security issues, and convention adherence;
  optionally run tests/lint/build; return severity-graded findings (`file:line` + concise fix
  suggestion) and a `PASS`/`CONCERNS`/`FAIL` verdict. Makes no edits.

> Note: plugin agents cannot use `hooks`, `mcpServers`, or `permissionMode` — none are relied on.

## 9. Optional integrations (generic detection only)

The skill core references **no** external plugin. The README has an *"Optional enhancements —
works nicely alongside, not required"* section listing examples (e.g. a dedicated planning/TDD
skill suite, an external code-review CLI, `gh` for real PRs). When such a capability is present
the relevant phase may prefer it; when absent, the bundled path is used. No behavior **depends**
on any of them.

## 10. Artifact formats

> These artifacts are generated by the skill **in the user's target project** — not in this
> plugin repo. Committed artifacts live under the target project's `docs/` (`docs/plan.md`,
> `docs/stories/`) with the generated `CLAUDE.md` at its root; `tmp/log.md` is gitignored
> runtime state.

### 10.1 `docs/plan.md` (committed)
Sections: Overview · Goals · Target users · Scope (In / Out) · Stories (table: id, title,
priority, acceptance criteria, depends-on, `[P]`) · Architecture · Non-functional requirements ·
Risks · **Clarifications** (must be empty) · **Sign-off** (`Approved by … on YYYY-MM-DD`).

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
  orchestrates and does not code. Log progress to `tmp/log.md`. Tests + lint + build must pass
  before a story is done."
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
- **Always escalate:** high-risk or large-blast-radius merges; 3× failure on a story; corrupted
  git state; any remaining ambiguity.

## 12. Error handling

| Situation | Response |
|---|---|
| Subagent fails / no output | Retry, or resume with specific feedback |
| Review findings remain | Fix → re-review (cap 3) → escalate |
| Tests/lint/build fail | Story is **not** done; loop or escalate |
| No sign-off | Implementation blocked |
| Not a git repo | Offer `git init` |
| No remote / no `gh` | Local `--no-ff` merge with PR-style message |
| Lost session | On resume, read `tmp/log.md` and continue |

## 13. Testing & release

- **Validate:** `claude plugin validate` before release.
- **Dry-run:** drive the full workflow against a tiny throwaway spec via a subagent to confirm
  each reference file is self-sufficient and the loop holds (per skill-testing best practice).
- **Docs:** `README.md` (install, usage, workflow, optional enhancements), `LICENSE` (MIT),
  `CHANGELOG.md`.

## 14. v1 scope vs roadmap

| In v1 | Roadmap (documented, not built) |
|---|---|
| Discovery w/ `[NEEDS CLARIFICATION]` | Per-epic retrospectives |
| Plan + hard sign-off gate | Parallel `[P]` *execution* |
| Self-contained story files | Story complexity scoring |
| Per-story build/review/fix loop | Cross-artifact consistency `/analyze` |
| Bundled builder + reviewer agents | Hook-enforced approval gate |
| Severity gates + deterministic checks | Pluggable external-reviewer adapters |
| `tmp/log.md` recovery; sprint checkpoints | Configurable model-tiering presets |

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
- Default implementation checkpoint: **sprint-level** (configurable).
