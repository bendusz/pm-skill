#!/usr/bin/env bash
# pm-skill hooks — shared library. Sourced by every hook; also a tiny CLI:
#   printf '%s' "$diff" | lib.sh scan   # exit 1 if secret-shaped content found
#
# Everything here is fail-open friendly: functions return non-zero rather than
# exiting, and callers treat failure as "allow".

# pm_root <cwd> — resolve the PROJECT root, not the session cwd.
# Order: $CLAUDE_PROJECT_DIR (documented hook variable, must be absolute + a dir)
# → git worktree top level → cwd unchanged (PM projects without git still work).
pm_root() {
  local cwd="$1" r=""
  case "${CLAUDE_PROJECT_DIR:-}" in
    /*) [ -d "$CLAUDE_PROJECT_DIR" ] && { printf '%s' "$CLAUDE_PROJECT_DIR"; return 0; } ;;
  esac
  if command -v git >/dev/null 2>&1; then
    r="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
  fi
  printf '%s' "$cwd"
}

# pm_relpath <root> <path> — canonical root-relative path of a (possibly
# not-yet-existing) target, or return 1 when the target is outside the root.
# Resolves symlinks and '..' through the deepest EXISTING ancestor, so
# 'pm/../src/app.py' classifies as 'src/app.py' and a symlinked directory
# cannot alias one prefix to another. No realpath -m (absent on macOS).
pm_relpath() {
  local root="$1" path="$2" dir rest="" parent full link hops=0
  root="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
  case "$path" in
    /*) ;;
    *) path="$root/$path" ;;
  esac
  # Resolve a FINAL symlink (to a file, or dangling) — `-d` below would stop at
  # its parent and classify the symlink's lexical location, letting e.g. an
  # existing docs/config -> src/config alias bypass the allowlists. Directory
  # symlinks are already resolved by the `pwd -P` canonicalization further down.
  while [ -L "$path" ]; do
    hops=$((hops+1)); [ "$hops" -gt 8 ] && return 1
    link="$(readlink "$path")" || return 1
    case "$link" in
      /*) path="$link" ;;
      *) path="${path%/*}/$link" ;;
    esac
  done
  dir="$path"
  while [ ! -d "$dir" ]; do
    rest="${dir##*/}${rest:+/$rest}"
    parent="${dir%/*}"
    [ -z "$parent" ] && parent="/"
    [ "$parent" = "$dir" ] && return 1
    dir="$parent"
  done
  dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
  case "/$rest/" in */../*|*/./*) return 1 ;; esac
  full="$dir${rest:+/$rest}"
  case "$full" in
    "$root") printf '.' ;;
    "$root"/*) printf '%s' "${full#"$root"/}" ;;
    *) return 1 ;;
  esac
}

# pm_actor_id <root> — globally unique actor id: slug of the FULL git
# user.email (v.bende@gmail.com → v-bende-gmail-com); fallback slug of
# user.name. Prints nothing and returns 1 when no identity is derivable —
# callers choose their own fallback (allow, or 'unknown-actor').
pm_actor_id() {
  local root="$1" src=""
  if command -v git >/dev/null 2>&1; then
    src="$(git -C "$root" config user.email 2>/dev/null)"
    [ -n "$src" ] || src="$(git -C "$root" config user.name 2>/dev/null)"
  fi
  [ -n "$src" ] || return 1
  src="$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+//; s/-+$//')"
  [ -n "$src" ] || return 1
  printf '%s' "$src"
}

# pm_secret_scan — read stdin; return 1 if it contains secret-shaped content,
# 0 when clean. Never echoes the matched value (it must not leak into logs).
# Two groups: token FORMATS stay case-sensitive; credential ASSIGNMENTS are
# case-insensitive and match quoted or unquoted values. Placeholders never
# trip: values starting '$' (env refs), '<' (templates), or '{' are excluded.
pm_secret_scan() {
  local buf
  buf="$(cat)"
  # Token formats (case-sensitive).
  if printf '%s' "$buf" | grep -qE \
    -e 'AKIA[0-9A-Z]{16}' \
    -e '-----BEGIN [A-Z ]*PRIVATE KEY' \
    -e 'gh[pousr]_[A-Za-z0-9]{30,}' \
    -e 'github_pat_[A-Za-z0-9_]{22,}' \
    -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
    -e 'sk-[A-Za-z0-9_-]{20,}' \
    -e 'AIza[0-9A-Za-z_-]{35}' \
    -e 'eyJ[A-Za-z0-9_-]{17,}\.eyJ[A-Za-z0-9_-]{10,}'
  then
    echo "secret-shaped token format detected" >&2
    return 1
  fi
  # Credential assignments (case-insensitive; quoted then unquoted).
  # shellcheck disable=SC2016  # the '$' is a literal inside a character class, not an expansion
  if printf '%s' "$buf" | grep -qiE \
    -e '(api[_-]?key|secret|token|passw(or)?d|credential)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_/+=.-]{8,}["'"'"']' \
    -e '(api[_-]?key|secret|token|passw(or)?d|credential)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_/+=.-]{8,}'
  then
    echo "credential assignment with a real-looking value detected" >&2
    return 1
  fi
  return 0
}

# CLI mode: `lib.sh scan` (used by the implementation loop's outgoing-diff scan).
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ] && [ "${1:-}" = "scan" ]; then
  pm_secret_scan
  exit $?
fi
