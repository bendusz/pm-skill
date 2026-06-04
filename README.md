# pm-skill — a Project/Product Manager skill for Claude Code

Turn Claude into a disciplined **Project / Product Manager** that discovers, plans, gets your
sign-off, decomposes work into stories, and **orchestrates** the build through specialist
subagents — review, fix, ship, and log — **without writing the code itself**.

One repeatable way of working:

> **discover → align → plan → sign-off → decompose → orchestrate → review → ship → log**

It is generic and self-contained: it works on a bare Claude Code install and gets richer if you
happen to have other tools.

## Install

```
/plugin marketplace add bendusz/pm-skill
/plugin install pm-skill@pm-skill
```

If it doesn't appear right away, restart your Claude Code session.

## Use

- Just describe the work — e.g. *"act as my PM to build a CLI todo app"* — and the
  `project-manager` skill activates, or
- run the command explicitly:

```
/pm-skill:pm build a CLI todo app
```

The PM runs discovery with you, writes a plan, and **waits for your explicit sign-off** before
building anything.

## How it works

| Phase | What happens |
|-------|--------------|
| Discovery | You and the PM agree the problem and the best solution; ambiguities are resolved first. |
| Plan & sign-off | A written `docs/plan.md` with testable acceptance criteria; **you approve it** before any code. |
| Decomposition | Sprints → self-contained story files under `docs/stories/`. |
| Implementation loop | Per story: **build → review → fix → (optional external review) → ship → log**, run by subagents. |
| Parallel stories | Independent `[P]` stories can build at once in isolated **git worktrees**, then integrate one at a time (opt-in; safe fallback to sequential). |
| Review gates | A separate read-only reviewer + the project's real test/lint/build gates; bounded fix loops. |
| Logging | A `tmp/log.md` logbook so a lost session can resume. |

Bundled specialist agents do the work — a builder (**`expert-builder`**), a risk-selected read-only
**review panel** (**`code-integrity-reviewer`**, **`architecture-reviewer`**, **`security-auditor`**),
a **`test-engineer`** (tests only), a **`debugger`** (read-only root-cause → fix plan), a
**`technical-writer`** (docs only), and a **`codebase-analyst`** for brownfield work. The PM stays an
orchestrator and protects its own context by handing each agent only what it needs.

Default check-in is **sprint-level** (you review at each sprint boundary); configurable to
story-level or fully autonomous.

## Safety

- **No implementation before your sign-off.**
- **Repository safety:** the PM never overwrites your files without asking, commits only what it
  created for the current story, runs `git init` only after asking, and never pushes without an
  explicit request.

## Optional enhancements (work alongside — not required)

pm-skill is fully functional on its own. If your environment also has any of these, the PM may
prefer them where useful — but nothing here is a dependency:

- A dedicated planning / TDD skill suite for richer discovery and planning.
- An external code-review tool (for example an OpenAI Codex–based reviewer, or another model's CLI)
  for the optional independent review step.
- `gh` plus a GitHub remote for real pull requests (otherwise the PM uses local merges).

## License

MIT — see [LICENSE](LICENSE).
