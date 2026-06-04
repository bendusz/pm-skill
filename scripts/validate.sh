#!/usr/bin/env bash
# Portable validation for the pm-skill plugin — runs locally and in CI (no `claude` CLI needed).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fail=0
err(){ echo "FAIL: $*" >&2; fail=1; }

command -v jq >/dev/null 2>&1 || { echo "validate.sh: jq is required" >&2; exit 2; }

# 1) JSON validity
for f in .claude-plugin/marketplace.json \
         plugins/pm-skill/.claude-plugin/plugin.json \
         plugins/pm-skill/hooks/hooks.json; do
  if [ -f "$f" ]; then jq empty "$f" 2>/dev/null || err "invalid JSON: $f"; else err "missing: $f"; fi
done

# 2) marketplace source resolves to the plugin dir
src="$(jq -r '.plugins[0].source' .claude-plugin/marketplace.json 2>/dev/null)"
[ -d "$src" ] || err "marketplace source is not a directory: $src"

# 3) required files
for f in plugins/pm-skill/skills/project-manager/SKILL.md README.md LICENSE CHANGELOG.md; do
  [ -f "$f" ] || err "missing required file: $f"
done

# 4) skill + agent frontmatter must declare name + description
for md in plugins/pm-skill/skills/project-manager/SKILL.md plugins/pm-skill/agents/*.md; do
  [ -f "$md" ] || continue
  head -n 12 "$md" | grep -q '^name:' || err "no 'name:' frontmatter in $md"
  head -n 12 "$md" | grep -q '^description:' || err "no 'description:' frontmatter in $md"
done

# 5) the sign-off hook must be executable
[ -x plugins/pm-skill/hooks/require-signoff.sh ] || \
  err "hook not executable: plugins/pm-skill/hooks/require-signoff.sh"

# 6) the installed plugin must stay generic (no third-party plugin names)
if grep -riE 'superpowers|skill-codex|\bcodex\b' plugins/pm-skill/ >/dev/null 2>&1; then
  err "third-party plugin name found under plugins/pm-skill/ (keep the artifact generic)"
fi

if [ "$fail" -eq 0 ]; then echo "validate.sh: OK"; else echo "validate.sh: FAILED" >&2; exit 1; fi
