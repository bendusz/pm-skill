#!/usr/bin/env bash
# pm-skill PreToolUse hook — block secret-shaped content from being written into pm/.
#
# pm/ is git-tracked, so a leaked credential there enters history — near-impossible to
# remove once pushed. This guard scans Write/Edit/MultiEdit content targeting pm/ for
# high-confidence secret shapes (key-material tokens, PEM headers, credential
# assignments) and blocks the write with exit 2.
#
# FAIL-OPEN by design, like require-signoff.sh: kill switch, no jq, unparseable input,
# or a target outside pm/ all ALLOW (exit 0). Patterns are deliberately high-confidence
# — this is a tripwire for accidents, not a scanner; prose ("rotate the API key") never
# trips it.
set -u

# Kill switch.
[ "${PM_SKILL_NO_ENFORCE:-}" = "1" ] && exit 0

# Need jq to parse the hook JSON safely; without it, allow.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

# Only guard writes into the tracked pm/ state directory.
case "$file" in
  "$cwd"/pm/*) ;;
  *) exit 0 ;;
esac

# Collect the content being written: Write.content, Edit.new_string, MultiEdit.edits[].new_string.
content="$(printf '%s' "$input" | jq -r \
  '[.tool_input.content // empty, .tool_input.new_string // empty]
   + [.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)"
[ -n "$content" ] || exit 0

# High-confidence secret shapes only (token formats + credential assignment with a real value).
if printf '%s' "$content" | grep -qE \
  -e 'AKIA[0-9A-Z]{16}' \
  -e '-----BEGIN [A-Z ]*PRIVATE KEY' \
  -e 'gh[pousr]_[A-Za-z0-9]{30,}' \
  -e 'github_pat_[A-Za-z0-9_]{22,}' \
  -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e 'AIza[0-9A-Za-z_-]{35}' \
  -e 'eyJ[A-Za-z0-9_-]{17,}\.eyJ[A-Za-z0-9_-]{10,}' \
  -e '(api[_-]?key|secret|token|passw(or)?d)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'<>]{8,}["'"'"']'
then
  rel="${file#"$cwd"/}"
  cat >&2 <<MSG
pm-skill: blocked a write to $rel — the content contains a secret-shaped string.
pm/ is git-tracked; secrets there enter history permanently. Reference the secret's
LOCATION (e.g. ".env on the box"), never its value, then retry the write.
(Set PM_SKILL_NO_ENFORCE=1 to disable this guard.)
MSG
  exit 2
fi

exit 0
