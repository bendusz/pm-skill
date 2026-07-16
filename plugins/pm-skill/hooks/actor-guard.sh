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

# Shared helpers (root discovery, canonical paths, actor identity); without them, allow.
libdir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
[ -f "$libdir/lib.sh" ] || exit 0
# shellcheck source=lib.sh disable=SC1091
. "$libdir/lib.sh"

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"
root="$(pm_root "$cwd")"

# Only guard files directly under pm/actors/ (canonical path).
rel="$(pm_relpath "$root" "$file")" || exit 0
case "$rel" in
  pm/actors/*) ;;
  *) exit 0 ;;
esac

# Only the two known per-actor file shapes; anything else in actors/ is allowed.
# Basename comes from the CANONICAL rel path — a symlink named after us must
# not authorize a write to the actor file it actually points at.
base="${rel##*/}"
case "$base" in
  *.HANDOFF.md) target="${base%.HANDOFF.md}" ;;
  *.json)       target="${base%.json}" ;;
  *)            exit 0 ;;
esac

# Derive our own actor id: slug of the FULL git user.email (globally unique),
# else user.name, via lib.sh. No derivable identity -> allow.
me="$(pm_actor_id "$root")" || exit 0
[ -n "$me" ] || exit 0

[ "$target" = "$me" ] && exit 0

cat >&2 <<MSG
pm-skill: blocked a write to pm/actors/$base — that is '$target's state file and you are '$me'.
Each actor writes only their own pm/actors/<id>.json and <id>.HANDOFF.md. Coordinate through
pm/pm-state.json (assignments) and pm/log.md instead.
(Set PM_SKILL_NO_ENFORCE=1 to disable this guard.)
MSG
exit 2
