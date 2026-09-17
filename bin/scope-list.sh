#!/usr/bin/env bash
#
# Show what is in scope and whether its graph is built.
#
set -euo pipefail
# Resolve through symlinks so this works when linked into ~/.local/bin.
# BSD readlink has no -f, so walk the links by hand.
_s="${BASH_SOURCE[0]}"
while [[ -L "$_s" ]]; do
  _d="$(cd -P "$(dirname "$_s")" && pwd)"
  _s="$(readlink "$_s")"
  [[ "$_s" == /* ]] || _s="$_d/$_s"
done
source "$(cd -P "$(dirname "$_s")" && pwd)/lib.sh"

rows="$(scope_rows)"
[[ -z "$rows" ]] && { info "nothing tracked yet — bin/scope-add.sh <path>"; exit 0; }

printf '%-20s %-18s %-10s %-12s %s\n' PROJECT SLOT MODE STATE BRANCH
while IFS=$'\t' read -r name path mode; do
  p="$(untildify "$path")"
  if [[ ! -d "$p" ]]; then
    printf '%-20s %-18s %-10s %-12s %s\n' "$name" "-" "$mode" "gone" "$path"
    continue
  fi
  found=0
  for slotdir in "$GRAPHS/$name"/*/; do
    [[ -d "$slotdir" ]] || continue
    slot="$(basename "$slotdir")"
    graph="$slotdir/graph.json"
    [[ -f "$graph" ]] || continue
    found=1
    wt="$(cat "$slotdir/.graphify_root" 2>/dev/null || echo "")"
    if [[ -z "$wt" || ! -d "$wt" ]]; then
      state="orphan"; branch="worktree gone"
    elif graph_is_fresh "$graph" "$wt"; then
      state="current"; branch="$(worktree_label "$wt")"
    else
      state="stale"; branch="$(worktree_label "$wt")"
    fi
    printf '%-20s %-18s %-10s %-12s %s\n' "$name" "$slot" "$mode" "$state" "$branch"
  done
  [[ $found -eq 0 ]] && printf '%-20s %-18s %-10s %-12s %s\n' "$name" "-" "$mode" "not built" "$path"
done <<<"$rows"

echo
echo "  'stale' rebuilds on the next bin/graph.sh call   'orphan' = worktree gone (bin/graph-gc.sh)"
