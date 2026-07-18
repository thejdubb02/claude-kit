#!/bin/bash
# WSG silo statusline — makes each Claude Code window announce which silo it is.
# Reads the session JSON on stdin (cwd, session name, model, context, git branch).

input=$(cat)

cwd=$(printf '%s' "$input"     | jq -r '.workspace.current_dir // ""')
sname=$(printf '%s' "$input"   | jq -r '.session_name // ""')
model=$(printf '%s' "$input"   | jq -r '.model.display_name // "?"')
branch=$(printf '%s' "$input"  | jq -r '.git.branch // ""')
pct=$(printf '%s' "$input"     | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Which silo is this window? Derived from the working directory.
case "$cwd" in
  */wsg-client-projects/clients*)   silo="CLIENTS";  icon="🌐" ;;
  */wsg-client-projects/skyhawk*)   silo="SKYHAWK";  icon="🦅" ;;
  */wsg-client-projects/mark*)      silo="MARK";     icon="🏨" ;;
  */wsg-client-projects/ventures*)  silo="VENTURES"; icon="🚀" ;;
  */wsg-client-projects*)           silo="MONOREPO"; icon="📦" ;;
  /root)                            silo="WSG OPS";  icon="🛠️" ;;
  *)                                silo=$(basename "$cwd"); icon="📁" ;;
esac

# Loudest possible warning: the Skyhawk silo is white-label. No WSG footprint, ever.
warn=""
[ "$silo" = "SKYHAWK" ] && warn=" ⚠️ WHITE-LABEL — ZERO WSG FOOTPRINT"

out="${icon} ${silo}"
[ -n "$sname" ] && out="${out} · ${sname}"
[ -n "$branch" ] && out="${out} · ${branch}"
out="${out} · ${model} · ${pct}% ctx${warn}"

printf '%s' "$out"
