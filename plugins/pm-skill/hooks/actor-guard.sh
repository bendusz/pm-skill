#!/usr/bin/env bash
# pm-skill PreToolUse hook — block writes to ANOTHER actor's state files under pm/actors/.
#
# Each person writes only their own pm/actors/<id>.json and <id>.HANDOFF.md; shared
# coordination happens in pm/pm-state.json (assignments) and pm/log.md. Writing someone
# else's position file is unambiguously an accident, so it is blocked (exit 2).
#
# FAIL-OPEN by design, like the other pm-skill hooks: kill switch, no jq, no git, no
# derivable identity, or a target outside pm/actors/ all ALLOW (exit 0).
set -u

# Kill switch.
[ "${PM_SKILL_NO_ENFORCE:-}" = "1" ] && exit 0

# Need jq to parse the hook JSON safely; without it, allow.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

# Only guard files directly under pm/actors/.
case "$file" in
  "$cwd"/pm/actors/*) ;;
  *) exit 0 ;;
esac

# Only the two known per-actor file shapes; anything else in actors/ is allowed.
base="${file##*/}"
case "$base" in
  *.HANDOFF.md) target="${base%.HANDOFF.md}" ;;
  *.json)       target="${base%.json}" ;;
  *)            exit 0 ;;
esac

# Derive our own actor id: email local part, else user.name, slugged. No identity -> allow.
command -v git >/dev/null 2>&1 || exit 0
src="$(git -C "$cwd" config user.email 2>/dev/null | cut -d@ -f1)"
[ -n "$src" ] || src="$(git -C "$cwd" config user.name 2>/dev/null)"
[ -n "$src" ] || exit 0
me="$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+//; s/-+$//')"
[ -n "$me" ] || exit 0

[ "$target" = "$me" ] && exit 0

cat >&2 <<MSG
pm-skill: blocked a write to pm/actors/$base — that is '$target's state file and you are '$me'.
Each actor writes only their own pm/actors/<id>.json and <id>.HANDOFF.md. Coordinate through
pm/pm-state.json (assignments) and pm/log.md instead.
(Set PM_SKILL_NO_ENFORCE=1 to disable this guard.)
MSG
exit 2
