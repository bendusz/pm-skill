#!/usr/bin/env bash
# pm-skill PreToolUse hook — block implementation writes until the plan is signed off.
#
# FAIL-OPEN by design. The hook ALLOWS (exit 0) on any uncertainty: kill switch,
# no jq, no state file, unparseable JSON, or a target outside the project tree.
# It BLOCKS (exit 2 + stderr reason) only when it is certain a PM-managed project
# is mid-flight and pre-sign-off, and the write targets a non-planning path.
#
# This means: for anyone who installs the plugin but is NOT running the PM skill,
# the hook is completely inert.
set -u

# Kill switch.
[ "${PM_SKILL_NO_ENFORCE:-}" = "1" ] && exit 0

# Need jq to parse the hook JSON safely; without it, allow.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

# Only active in a PM-managed project.
state="$cwd/tmp/pm-state.json"
[ -f "$state" ] || exit 0

# Only enforce while the plan is explicitly not yet signed off.
# NB: use a plain lookup, not `// empty` — jq's `//` treats `false` as empty,
# which would hide the very value we need to read.
signed="$(jq -r '.signed_off' "$state" 2>/dev/null)"
[ "$signed" = "false" ] || exit 0

# Only enforce for writes inside the project tree.
case "$file" in
  "$cwd"/*) ;;
  *) exit 0 ;;
esac
rel="${file#"$cwd"/}"

# Allow the planning artifacts the PM legitimately writes before sign-off.
case "$rel" in
  docs/*|tmp/*|.git/*|CLAUDE.md|.gitignore) exit 0 ;;
esac

# Otherwise this is an implementation write before sign-off — block it.
cat >&2 <<'MSG'
pm-skill: implementation is blocked until the plan is signed off.
A PM-managed project is in planning (tmp/pm-state.json: signed_off=false).
Get the user's explicit approval on docs/plan.md, record it, and set
signed_off=true in tmp/pm-state.json — then implementation may proceed.
(Set PM_SKILL_NO_ENFORCE=1 to disable this gate.)
MSG
exit 2
