#!/usr/bin/env bash
#
# Ask a question against one tracked project's graph.
#
#   bin/query.sh <name> "how does auth reach the database?"
#
# Queries the PRIMARY checkout's graph by project name. To query the worktree
# you are standing in (and rebuild it if stale), use bin/graph.sh query instead.
#
# Graphs live centrally here, so every graphify read command needs --graph:
#   graphify explain "Thing"  --graph graphs/<name>/_primary/graph.json
#   graphify global path                 # crosses tracked projects
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_graphify

NAME="${1:-}"; shift || true
[[ -n "$NAME" && $# -gt 0 ]] || die 'usage: bin/query.sh <name> "<question>" [graphify query flags]'

graph="$(slot_json "$NAME" _primary)"
[[ -f "$graph" ]] || die "no graph for '$NAME' — bin/refresh.sh $NAME"

exec graphify query "$@" --graph "$graph"
