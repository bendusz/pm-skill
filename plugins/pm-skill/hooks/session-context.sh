#!/usr/bin/env bash
# pm-skill SessionStart hook — inject a tiny resume pointer when the project is PM-managed.
#
# Fires on startup, resume, /clear, and post-compaction (SessionStart source=compact); stdout
# becomes context for the new session. Emits a few short lines pointing at the pm/ state so a
# fresh or freshly-compacted session re-grounds itself without re-discovery — and stays
# completely SILENT (exit 0, no output) in any project that is not PM-managed.
#
# Fail-open: kill switch, missing state, or no jq all degrade gracefully.
set -u

[ "${PM_SKILL_NO_ENFORCE:-}" = "1" ] && exit 0

input="$(cat)"
cwd="$PWD"
if command -v jq >/dev/null 2>&1; then
  c="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
  [ -n "$c" ] && cwd="$c"
fi

# PM-managed? Tracked pm/ first; legacy pre-0.8 tmp/ as fallback.
state="$cwd/pm/pm-state.json"
if [ ! -f "$state" ]; then
  if [ -f "$cwd/tmp/pm-state.json" ]; then
    echo "pm-skill: PM-managed project with state in the legacy tmp/ location."
    echo "Run /pm-skill:resume to migrate it to the tracked pm/ directory and continue."
  fi
  exit 0
fi

echo "pm-skill: this is a PM-managed project (pm/pm-state.json present)."

if command -v jq >/dev/null 2>&1 && jq empty "$state" 2>/dev/null; then
  # NB: signed_off is a boolean — jq's `//` treats false as empty, so use an explicit null check.
  summary="$(jq -r '"phase=\(.phase // "?") story=\(.current_story // "-") status=\(.current_story_status // "-") signed_off=\(if .signed_off == null then "?" else .signed_off end) next=\(.next // "?")"' "$state" 2>/dev/null)"
  [ -n "$summary" ] && echo "$summary"
  # Handoff freshness: timestamps are "YYYY-MM-DD HH:MM", so string comparison is safe.
  hw="$(jq -r '.handoff_written // empty' "$state" 2>/dev/null)"
  up="$(jq -r '.updated // empty' "$state" 2>/dev/null)"
  if [ -f "$cwd/pm/HANDOFF.md" ] && [ -n "$hw" ]; then
    if [ -n "$up" ] && [ "$up" \> "$hw" ]; then
      echo "pm/HANDOFF.md is STALE (state moved on after it was written) — trust pm/pm-state.json + pm/log.md."
    else
      echo "A current pm/HANDOFF.md briefing exists — read it first; it replaces re-discovery."
    fi
  fi
fi

echo "To continue: run /pm-skill:resume (or read the pm/ files directly). Before ending a long session, offer /pm-skill:handoff."
exit 0
