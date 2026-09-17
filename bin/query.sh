#!/usr/bin/env bash
#
# Ask a question against one tracked project's graph.
#
#   bin/query.sh <name> "how does auth reach the database?"
#
# Graphs live centrally here, so every graphify read command needs --graph.
# Same idea for the others:
#   graphify explain "Thing"  --graph graphs/<name>/graph.json
#   graphify path "A" "B"     --graph graphs/<name>/graph.json
#   graphify global path                 # crosses tracked projects
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_graphify

NAME="${1:-}"; shift || true
[[ -n "$NAME" && $# -gt 0 ]] || die 'usage: bin/query.sh <name> "<question>" [graphify query flags]'

graph="$GRAPHS/$NAME/graph.json"
[[ -f "$graph" ]] || die "no graph for '$NAME' — bin/refresh.sh $NAME"

exec graphify query "$@" --graph "$graph"
