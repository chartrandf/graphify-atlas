#!/usr/bin/env bash
#
# Show what is in scope and whether its graph is built.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

rows="$(scope_rows)"
[[ -z "$rows" ]] && { info "nothing tracked yet — bin/scope-add.sh <path>"; exit 0; }

printf '%-24s %-12s %-12s %s\n' NAME MODE GRAPH PATH
while IFS=$'\t' read -r name path mode; do
  graph="$GRAPHS/$name/graph.json"
  if [[ -f "$graph" ]]; then
    size="$(du -h "$graph" | cut -f1 | tr -d ' ')"
  elif [[ -d "$(untildify "$path")" ]]; then
    size="-"
  else
    size="gone"
  fi
  printf '%-24s %-12s %-12s %s\n' "$name" "$mode" "$size" "$path"
done <<<"$rows"

echo
echo "  '-' = not built yet (bin/refresh.sh)   'gone' = folder no longer exists"
