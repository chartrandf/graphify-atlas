#!/usr/bin/env bash
#
# The entry point an agent calls. Resolves the graph for the worktree you are
# STANDING IN, and refuses to serve one that does not match it.
#
#   graph.sh ensure [dir]          resolve + rebuild if stale; prints the graph path
#   graph.sh query "<question>" [dir]
#   graph.sh status [dir]          what would be used, and whether it is current
#   graph.sh path [dir]            graph path only, no rebuild (empty if absent)
#   graph.sh list                  every tracked project and slot
#   graph.sh gc [--prune]          drop slots whose worktree is gone
#   graph.sh refresh [args...]     rebuild by project name
#
# Installed globally as `gatlas` by bin/install-cli.sh, so an agent can call it
# from inside any project without knowing where this repo lives.
#
# <dir> defaults to $PWD, so an agent just runs it from wherever it is working.
#
# Why this exists: graphify graphs a DIRECTORY. With worktrees and branch
# switching, reading graphs/<project>/graph.json directly means silently
# answering from another branch's parse. Going through `ensure` makes that
# impossible — the graph is keyed to the worktree, and a stale one is rebuilt
# before it is handed back.
#
# Exit codes: 0 ok · 2 not a tracked project · 1 error
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

LOCKED=""
# Must return 0: this runs as the EXIT trap, and a trailing `&&` that evaluates
# false would make every successful run exit non-zero.
cleanup() { [[ -n "$LOCKED" ]] && slot_unlock "$LOCKED"; return 0; }
trap cleanup EXIT INT TERM

# Resolve <dir>, rebuilding the slot when it does not match the worktree.
# Prints the graph path on success.
ensure() {
  local dir="$1" row project slot wt mode out graph
  row="$(resolve_slot "$dir")" || {
    warn "not a tracked project: $dir"
    warn "add it with: $ROOT/bin/scope-add.sh <project path>"
    return 2
  }
  IFS=$'\t' read -r project slot wt <<<"$row"
  mode="$(scope_mode "$project")"; [[ -n "$mode" ]] || mode="code-only"
  out="$(slot_dir "$project" "$slot")"
  graph="$(slot_json "$project" "$slot")"

  if graph_is_fresh "$graph" "$wt"; then
    printf '%s\n' "$graph"
    return 0
  fi

  need_graphify
  if ! slot_lock "$out"; then
    # Someone else is building and is taking too long. An out-of-date answer
    # beats no answer, but say so — never let it pass for current.
    warn "$project/$slot: timed out waiting for a concurrent build"
    if [[ -f "$graph" ]]; then
      warn "serving the existing graph, which is NOT current"
      printf '%s\n' "$graph"
      return 0
    fi
    return 1
  fi
  LOCKED="$out"

  # Re-check under the lock: whoever we queued behind has probably just built it.
  if ! graph_is_fresh "$graph" "$wt"; then
    info "$project/$slot  ($(worktree_label "$wt"))  rebuilding" >&2
    build_slot "$project" "$slot" "$wt" "$mode" >&2 || { slot_unlock "$out"; LOCKED=""; return 1; }
  fi

  slot_unlock "$out"; LOCKED=""
  printf '%s\n' "$graph"
}

status() {
  local dir="$1" row project slot wt graph built head state
  row="$(resolve_slot "$dir")" || { echo "not tracked: $dir"; return 2; }
  IFS=$'\t' read -r project slot wt <<<"$row"
  graph="$(slot_json "$project" "$slot")"
  built="$(graph_built_commit "$graph" 2>/dev/null || echo '-')"
  head="$(git -C "$wt" rev-parse HEAD 2>/dev/null || echo '-')"
  if [[ ! -f "$graph" ]]; then state="not built"
  elif graph_is_fresh "$graph" "$wt"; then state="current"
  elif [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then state="stale (uncommitted changes)"
  else state="stale (HEAD moved)"; fi

  printf '%-12s %s\n' project  "$project"
  printf '%-12s %s\n' slot     "$slot"
  printf '%-12s %s\n' worktree "$wt"
  printf '%-12s %s\n' branch   "$(worktree_label "$wt")"
  printf '%-12s %s\n' "HEAD"   "${head:0:8}"
  printf '%-12s %s\n' "built"  "${built:0:8}"
  printf '%-12s %s\n' graph    "$graph"
  printf '%-12s %s\n' state    "$state"
}

CMD="${1:-}"; shift || true
case "$CMD" in
  ensure) ensure "${1:-$PWD}" ;;
  status) status "${1:-$PWD}" ;;
  path)
    row="$(resolve_slot "${1:-$PWD}")" || exit 2
    IFS=$'\t' read -r project slot _ <<<"$row"
    g="$(slot_json "$project" "$slot")"
    [[ -f "$g" ]] && printf '%s\n' "$g"
    ;;
  query)
    q="${1:-}"; [[ -n "$q" ]] || die 'usage: bin/graph.sh query "<question>" [dir]'
    shift || true
    need_graphify
    graph="$(ensure "${1:-$PWD}")" || exit $?
    exec graphify query "$q" --graph "$graph"
    ;;
  list)    exec "$ROOT/bin/scope-list.sh" "$@" ;;
  gc)      exec "$ROOT/bin/graph-gc.sh" "$@" ;;
  refresh) exec "$ROOT/bin/refresh.sh" "$@" ;;
  ""|-h|--help)
    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0" ;;
  *) die "unknown command: $CMD (ensure|query|status|path|list|gc|refresh)" ;;
esac
