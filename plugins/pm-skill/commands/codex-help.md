---
description: Ask the OpenAI Codex CLI for a second opinion — advice, a recommendation, or help with a decision — on the current work. Reserve for consequential changes, not routine questions.
---

Ask **Codex** (OpenAI's coding agent CLI) a specific question and relay its answer. This is a
second pair of eyes from an independent model — use it **sparingly**: real design decisions,
risky refactors, tricky tradeoffs. Not for routine questions you can answer yourself.

Arguments: $ARGUMENTS

## 1. Parse arguments

- **model=<id>** — default `gpt-5.6-sol` (judgment work gets the top tier).
- **effort=<level>** — `minimal|low|medium|high|xhigh` (model-dependent `max`/`ultra`);
  default `medium`.
- Everything else is the **question**. If empty, ask the user what they want Codex's opinion on.

## 2. Preflight

1. `command -v codex` — if missing, stop: install with `npm install -g @openai/codex` or
   `brew install codex`.
2. `codex login status` — non-zero exit → stop; tell the user to run `codex login` (or set
   `CODEX_API_KEY`).

## 3. Compose the prompt

Codex can read the repo but knows nothing about this conversation. Write a self-contained brief:
the question, the relevant file paths, the options being weighed with their tradeoffs, and any
constraints (conventions, deadlines, non-negotiables). End with:
`Give a concrete recommendation and your reasoning. Read the referenced files before answering.`

## 4. Run

From the repo root (`--skip-git-repo-check` if not in one):

```
codex exec --sandbox read-only --ephemeral --color never \
  -m "$MODEL" -c model_reasoning_effort="$EFFORT" \
  -o <scratch file> "<prompt>"
```

Never pass `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, or `--yolo`. On non-zero
exit, report the stderr cause (auth, usage error) instead of an answer.

## 5. Relay

Read the scratch file and present Codex's answer, clearly attributed ("Codex (gpt-…) recommends
…"), followed by your own take — where you agree, where you differ, and why. You own the final
recommendation; Codex is one input. If `pm/log.md` exists, append one line:
`- <date> codex-help: <question gist> → <answer gist>`.
