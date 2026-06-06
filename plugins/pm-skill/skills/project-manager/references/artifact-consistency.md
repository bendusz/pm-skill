# Artifact Consistency (Analyze)

A **read-only** quality and consistency pass across the PM artifacts — after the plan is drafted and
before decomposition (optionally before sign-off, for larger projects). It finds gaps and
contradictions; it **never** fixes them. Driven by `/pm-skill:analyze`.

## Read-only contract
Read the artifacts; produce a report. **Never** edit, create, scaffold, or fix anything — not even
logs or state. Offer remediation as *suggestions* only. If the artifact set is large, delegate the
reading to a read-only `general-purpose`/`Explore` subagent and take back only the findings.

## Inputs (whichever exist)
`docs/constitution.md`, `docs/spec.md`, `docs/plan.md`, `docs/stories/*.md`, `tmp/pm-state.json`,
`tmp/log.md`. Note in the report any that are absent.

## What to detect
- **Clarifications:** unresolved `[NEEDS CLARIFICATION]` markers in the spec or plan.
- **Requirement coverage:** spec requirements (`FR-`/`AC-`) with **no** story that `Covers:` them.
- **Story grounding:** stories that cover **no** requirement (orphan scope).
- **Testability:** acceptance criteria that are not observable/testable as written.
- **Verification:** stories missing a concrete verification command; the plan missing real commands.
- **Sign-off:** missing or inconsistent sign-off across `docs/plan.md`, `tmp/log.md`, and
  `tmp/pm-state.json`.
- **Constitution alignment:** plan/stories that conflict with a rule in `docs/constitution.md`.
- **Parallel safety:** `[P]` stories with **overlapping** `Touches`; `[P]` stories with blank `Touches`.
- **Dependencies:** `depends-on` pointing at a missing/invalid story ID; dependency cycles.
- **Gate references:** stories naming a gate not listed in `docs/plan.md`'s Commands.
- **Risk lenses:** stories that appear security-sensitive (auth, secrets, untrusted input, I/O, deps)
  with nothing indicating `security-auditor` will run; architecture-changing stories with nothing
  indicating `architecture-reviewer` will run.
- **Terminology drift:** the same concept named differently across spec, plan, and stories.
- **State sanity:** stale or contradictory `tmp/pm-state.json` / `tmp/log.md` vs the committed artifacts.

## Severities
- **CRITICAL** — blocks safe delivery, or violates the constitution or the sign-off rule.
- **HIGH** — likely to cause a wrong implementation.
- **MEDIUM** — a quality or coverage gap.
- **LOW** — clarity, wording, or minor consistency.

## Report format
```
## PM Artifact Analysis Report
| ID | Category | Severity | Location | Finding | Recommendation |
|----|----------|----------|----------|---------|----------------|

## Coverage Summary
| Requirement | Covered by stories | Notes |
|-------------|-------------------|-------|

## Unmapped Stories
<stories that cover no requirement, each with a note>

## Constitution Alignment
<rule by rule: aligned / at-risk / violated, with the evidence>

## Next Actions
<ordered, specific remediation suggestions — what to fix and where>
```

## After the report
This is a gate of judgement, not automation: present the report, then let the user (or the PM in a
later, non-analysis step) act on it. Resolve **CRITICAL** and **HIGH** findings before sign-off, or
before the implementation loop begins.
