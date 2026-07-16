#!/usr/bin/env bash
# Behavioral tests for the pm-skill hooks — table-driven stdin fixtures.
# Each case builds a throwaway project, pipes hook-shaped JSON to a hook, and
# asserts the exit code (0 = allow/silent, 2 = block). Run from the repo root:
#   bash scripts/test-hooks.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOKS="$ROOT/plugins/pm-skill/hooks"
pass=0 fail=0
cleanup_dirs=()
trap 'for d in "${cleanup_dirs[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done' EXIT

# ---------- helpers ----------

# NB: new_proj runs in a $(…) subshell, so it cannot register cleanup itself —
# every caller must append its result to cleanup_dirs in the parent shell.
new_proj() { # new_proj [signed_off] -> echoes project dir
  local signed="${1:-false}" d
  d="$(mktemp -d)"
  d="$(cd "$d" && pwd -P)"   # macOS mktemp returns /var/… symlinked via /private
  mkdir -p "$d/pm/actors" "$d/src" "$d/docs" "$d/packages/foo"
  printf '{"signed_off":%s,"phase":"implementation"}\n' "$signed" > "$d/pm/pm-state.json"
  git -C "$d" init -q
  git -C "$d" config user.email "casey@example.com"
  git -C "$d" config user.name "Casey Example"
  printf '%s' "$d"
}

json_write() { # json_write <cwd> <file_path>
  jq -cn --arg cwd "$1" --arg fp "$2" '{cwd:$cwd, tool_input:{file_path:$fp, content:"x"}}'
}

json_content() { # json_content <cwd> <file_path> <content>
  jq -cn --arg cwd "$1" --arg fp "$2" --arg c "$3" '{cwd:$cwd, tool_input:{file_path:$fp, content:$c}}'
}

t() { # t <name> <expected-exit> <hook> <stdin> [VAR=val ...]
  local name="$1" want="$2" hook="$3" stdin="$4"; shift 4
  local got
  printf '%s' "$stdin" | env -u CLAUDE_PROJECT_DIR -u PM_SKILL_NO_ENFORCE "$@" bash "$HOOKS/$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: $name (hook=$hook want=$want got=$got)"
  fi
}

# session-context is judged on OUTPUT, not exit code (always exits 0)
t_out() { # t_out <name> <grep-pattern|-EMPTY-> <stdin> [VAR=val ...]
  local name="$1" pat="$2" stdin="$3"; shift 3
  local out
  out="$(printf '%s' "$stdin" | env -u CLAUDE_PROJECT_DIR -u PM_SKILL_NO_ENFORCE "$@" bash "$HOOKS/session-context.sh" 2>/dev/null)"
  local ok=1
  if [ "$pat" = "-EMPTY-" ]; then
    [ -z "$out" ] && ok=0
  else
    printf '%s' "$out" | grep -q "$pat" && ok=0
  fi
  if [ "$ok" = 0 ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: $name (session-context output: '$out')"
  fi
}

# ---------- require-signoff.sh ----------

P="$(new_proj false)"; cleanup_dirs+=("$P")

t "signoff: blocks implementation write pre-sign-off" 2 require-signoff.sh \
  "$(json_write "$P" "$P/src/app.py")"

t "signoff: allows planning write (docs/)" 0 require-signoff.sh \
  "$(json_write "$P" "$P/docs/plan.md")"

t "signoff: allows pm/ write" 0 require-signoff.sh \
  "$(json_write "$P" "$P/pm/log.md")"

t "signoff: allows outside-project write" 0 require-signoff.sh \
  "$(json_write "$P" "/etc/hosts")"

t "signoff: allows when kill switch set" 0 require-signoff.sh \
  "$(json_write "$P" "$P/src/app.py")" PM_SKILL_NO_ENFORCE=1

t "signoff: allows on malformed JSON (fail-open)" 0 require-signoff.sh "not json {"

PS="$(new_proj true)"; cleanup_dirs+=("$PS")
t "signoff: allows implementation write after sign-off" 0 require-signoff.sh \
  "$(json_write "$PS" "$PS/src/app.py")"

# F1 — subdirectory launches must still find pm/pm-state.json at the root
t "signoff: F1 subdir cwd + CLAUDE_PROJECT_DIR still blocks" 2 require-signoff.sh \
  "$(json_write "$P/packages/foo" "$P/src/app.py")" CLAUDE_PROJECT_DIR="$P"

t "signoff: F1 subdir cwd + git-toplevel fallback still blocks" 2 require-signoff.sh \
  "$(json_write "$P/packages/foo" "$P/src/app.py")"

# F2 — traversal and symlink aliases must classify by the REAL target
t "signoff: F2 pm/../src traversal blocks" 2 require-signoff.sh \
  "$(json_write "$P" "$P/pm/../src/app.py")"

ln -s "$P/src" "$P/docs/impl-link"
t "signoff: F2 symlink under docs/ escaping to src/ blocks" 2 require-signoff.sh \
  "$(json_write "$P" "$P/docs/impl-link/app.py")"

# Final-symlink target (an existing docs/config -> src/config alias) must
# classify as the REAL file, not the symlink's lexical location.
touch "$P/src/config.py"
ln -s "$P/src/config.py" "$P/docs/config.md"
t "signoff: F2 final symlink to src/ file blocks" 2 require-signoff.sh \
  "$(json_write "$P" "$P/docs/config.md")"

# ---------- pm-secrets-guard.sh ----------

G="$(new_proj false)"; cleanup_dirs+=("$G")

t "secrets: allows prose in pm/" 0 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "rotate the API key on the box")"

t "secrets: blocks quoted lowercase assignment" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "api_key = \"zq9x7c2v8b4n6m1k\"")"

# F3 — case-insensitive + unquoted values
t "secrets: F3 blocks UPPERCASE quoted assignment" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "API_KEY = \"zq9x7c2v8b4n6m1k\"")"

t "secrets: F3 blocks unquoted assignment" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "API_KEY=abcdefghijklmno")"

t "secrets: F3 blocks 'Password: value' form" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "Password: hunter2hunter2")"

t "secrets: F3 placeholder env ref never trips" 0 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "TOKEN=\$GITHUB_TOKEN and api_key = \"\$FROM_ENV_VAR\"")"

t "secrets: F3 <placeholder> never trips" 0 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "token = \"<rotate-me-later>\"")"

t "secrets: blocks AWS token format" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "key AKIAIOSFODNN7EXAMPLE ok")"

t "secrets: blocks GitHub PAT format" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "ghp_abcdefghijklmnopqrstuvwxyz012345")"

t "secrets: blocks PEM header" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "-----BEGIN RSA PRIVATE KEY-----")"

t "secrets: ignores writes outside pm/" 0 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/src/config.py" "API_KEY=abcdefghijklmno")"

# F2 also applies here: traversal INTO pm/ must still be guarded
t "secrets: F2 docs/../pm traversal still guarded" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/docs/../pm/log.md" "API_KEY=abcdefghijklmno")"

# Final symlink INTO pm/ must still be guarded
touch "$G/pm/log.md"
ln -s "$G/pm/log.md" "$G/docs/note.md"
t "secrets: F2 final symlink into pm/ still guarded" 2 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/docs/note.md" "API_KEY=abcdefghijklmno")"

# Quoted prose values (spaces) must NOT trip — tripwire, not a prose scanner
t "secrets: quoted prose with spaces never trips" 0 pm-secrets-guard.sh \
  "$(json_content "$G" "$G/pm/log.md" "Password: \"use a sentence here\"")"

# ---------- actor-guard.sh ----------

A="$(new_proj false)"; cleanup_dirs+=("$A")   # git identity casey@example.com

t "actor: own state file allowed" 0 actor-guard.sh \
  "$(json_write "$A" "$A/pm/actors/casey-example-com.json")"

t "actor: other actor's file blocked" 2 actor-guard.sh \
  "$(json_write "$A" "$A/pm/actors/jordan-example-com.json")"

t "actor: other actor's HANDOFF blocked" 2 actor-guard.sh \
  "$(json_write "$A" "$A/pm/actors/jordan-example-com.HANDOFF.md")"

t "actor: non-actor file in actors/ allowed" 0 actor-guard.sh \
  "$(json_write "$A" "$A/pm/actors/README.txt")"

# F4 — same local part, different domain = DIFFERENT actor now
t "actor: F4 cross-domain same local part is another actor" 2 actor-guard.sh \
  "$(json_write "$A" "$A/pm/actors/casey-other-org.json")"

t "actor: F4 bare local-part id is no longer ours (pre-0.10.1 orphan)" 2 actor-guard.sh \
  "$(json_write "$A" "$A/pm/actors/casey.json")"

# ---------- session-context.sh ----------

S="$(new_proj false)"; cleanup_dirs+=("$S")
printf '{"actor":"casey-example-com","current_story":"S1-1"}\n' > "$S/pm/actors/casey-example-com.json"

t_out "session: emits pointer in PM project" "PM-managed" \
  "$(jq -cn --arg cwd "$S" '{cwd:$cwd, source:"startup"}')"

# F1 — a subdirectory session must still find the project state
t_out "session: F1 subdir cwd still finds state (git fallback)" "PM-managed" \
  "$(jq -cn --arg cwd "$S/packages/foo" '{cwd:$cwd, source:"startup"}')"

t_out "session: F1 subdir cwd + CLAUDE_PROJECT_DIR finds state" "PM-managed" \
  "$(jq -cn --arg cwd "$S/packages/foo" '{cwd:$cwd, source:"startup"}')" CLAUDE_PROJECT_DIR="$S"

# F4 — the full-email id resolves to OUR actor file
t_out "session: F4 full-email actor id is recognized as you" "you (casey-example-com)" \
  "$(jq -cn --arg cwd "$S" '{cwd:$cwd, source:"startup"}')"

N="$(mktemp -d)"; cleanup_dirs+=("$N")
t_out "session: silent outside PM projects" "-EMPTY-" \
  "$(jq -cn --arg cwd "$N" '{cwd:$cwd, source:"startup"}')"

# ---------- lib.sh scan CLI (F5) ----------

if [ -f "$HOOKS/lib.sh" ]; then
  if printf 'diff\n+API_KEY=abcdefghijklmno\n' | bash "$HOOKS/lib.sh" scan >/dev/null 2>&1; then
    fail=$((fail+1)); echo "FAIL: lib scan: secret-bearing diff must exit non-zero"
  else
    pass=$((pass+1))
  fi
  if printf 'diff\n+class APIClient: pass\n' | bash "$HOOKS/lib.sh" scan >/dev/null 2>&1; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "FAIL: lib scan: APIClient label must NOT trip the scan"
  fi
else
  fail=$((fail+1)); echo "FAIL: lib scan: hooks/lib.sh missing"
fi

# ---------- summary ----------

echo "test-hooks: $pass passed, $fail failed"
[ "$fail" = 0 ] || { echo "test-hooks: FAILED"; exit 1; }
echo "test-hooks: OK"
