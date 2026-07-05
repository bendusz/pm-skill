#!/usr/bin/env bash
# Portable validation for the pm-skill plugin — runs locally and in CI (no `claude` CLI needed).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2
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

# 5) every bundled hook script must be executable
for h in plugins/pm-skill/hooks/*.sh; do
  [ -x "$h" ] || err "hook not executable: $h"
done

# 6) the installed plugin must stay generic (no third-party plugin names)
if grep -riE 'superpowers|skill-codex|\bcodex\b' plugins/pm-skill/ >/dev/null 2>&1; then
  err "third-party plugin name found under plugins/pm-skill/ (keep the artifact generic)"
fi

# 7) every references/<x>.md named in SKILL.md exists
skill=plugins/pm-skill/skills/project-manager/SKILL.md
if [ -f "$skill" ]; then
  while IFS= read -r r; do
    [ -f "plugins/pm-skill/skills/project-manager/$r" ] || err "SKILL.md references missing file: $r"
  done < <(grep -oE 'references/[a-z0-9-]+\.md' "$skill" | sort -u)
fi

# 8) every *.template referenced (path or bare name) in skills/commands/agents exists
while IFS= read -r t; do
  [ -f "plugins/pm-skill/templates/$t" ] || err "referenced template missing: $t"
done < <(grep -rhoE '[A-Za-z0-9._-]+\.template' plugins/pm-skill/skills plugins/pm-skill/commands plugins/pm-skill/agents 2>/dev/null | sort -u)

# 9) every command has 'description:' frontmatter
for md in plugins/pm-skill/commands/*.md; do
  [ -f "$md" ] || continue
  head -n 6 "$md" | grep -q '^description:' || err "no 'description:' frontmatter in $md"
done

# 10) JSON templates parse
for f in plugins/pm-skill/templates/pm-state.json.template \
         plugins/pm-skill/templates/claude-settings-hardening.json.template; do
  [ -f "$f" ] && { jq empty "$f" 2>/dev/null || err "invalid JSON template: $f"; }
done

# 11) CHANGELOG top version matches plugin.json version
pv="$(jq -r '.version' plugins/pm-skill/.claude-plugin/plugin.json 2>/dev/null)"
cv="$(grep -m1 -oE '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md 2>/dev/null | awk '{print $2}')"
{ [ -n "$pv" ] && [ "$pv" = "$cv" ]; } || err "version mismatch: plugin.json=$pv CHANGELOG top=$cv"

# 12) keep the artifact generic and self-contained (no external jargon)
if grep -rnE '/speckit|\btmux\b|\bsockets?\b|\bPi\b' README.md plugins/pm-skill >/dev/null 2>&1; then
  err "forbidden reference (speckit/tmux/socket/Pi) found"
fi

if [ "$fail" -eq 0 ]; then echo "validate.sh: OK"; else echo "validate.sh: FAILED" >&2; exit 1; fi
