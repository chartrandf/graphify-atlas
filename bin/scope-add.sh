#!/usr/bin/env bash
#
# Put a local folder in scope: record it in scope.tsv, build its graph into
# graphs/<name>/, and (optionally) wire it into Claude Code.
#
#   bin/scope-add.sh <path> [options]
#
#   --name NAME        registry name (default: slug of the folder name)
#   --semantic         run semantic extraction too (needs an API key; sends code
#                      to a model backend). Default is --code-only: structural
#                      parsing on this machine, nothing leaves it.
#   --claude           register the graph with Claude Code for that project:
#                      `graphify install --project` + a local-scope MCP server
#   --ignore-template  drop templates/graphifyignore into the project as
#                      .graphifyignore, if it has none
#   --no-extract       record it only; build later with bin/refresh.sh
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NAME="" MODE="code-only" WIRE_CLAUDE=0 IGNORE_TPL=0 EXTRACT=1 TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)            NAME="${2:-}"; shift 2 ;;
    --semantic)        MODE="semantic"; shift ;;
    --claude)          WIRE_CLAUDE=1; shift ;;
    --ignore-template) IGNORE_TPL=1; shift ;;
    --no-extract)      EXTRACT=0; shift ;;
    -h|--help)         awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    -*)                die "unknown option: $1" ;;
    *)                 [[ -n "$TARGET" ]] && die "one path at a time"; TARGET="$1"; shift ;;
  esac
done

[[ -n "$TARGET" ]] || die "usage: bin/scope-add.sh <path> [--name N] [--semantic] [--claude]"
[[ -d "$TARGET" ]] || die "not a directory: $TARGET"

ABS="$(cd "$TARGET" && pwd)"
[[ -z "$NAME" ]] && NAME="$(slugify "$(basename "$ABS")")"
[[ -n "$NAME" ]] || die "could not derive a name — pass --name"

existing="$(scope_lookup "$NAME")"
if [[ -n "$existing" ]]; then
  prev="$(untildify "$(cut -f1 <<<"$existing")")"
  [[ "$prev" == "$ABS" ]] || die "name '$NAME' already points at $prev — pass a different --name"
  info "$NAME already tracked"
else
  printf '%s\t%s\t%s\n' "$NAME" "$(tildify "$ABS")" "$MODE" >> "$SCOPE"
  info "tracked $NAME -> $(tildify "$ABS")  ($MODE)"
fi

if [[ $IGNORE_TPL -eq 1 ]]; then
  if [[ -e "$ABS/.graphifyignore" ]]; then
    info "$ABS/.graphifyignore exists, leaving it alone"
  else
    cp "$ROOT/templates/graphifyignore" "$ABS/.graphifyignore"
    info "wrote $ABS/.graphifyignore"
  fi
fi

[[ $EXTRACT -eq 1 ]] && "$ROOT/bin/refresh.sh" "$NAME"

if [[ $WIRE_CLAUDE -eq 1 ]]; then
  need_graphify
  info "registering with Claude Code (project scope)"
  ( cd "$ABS" && graphify install --project --platform claude )
  if command -v claude >/dev/null 2>&1; then
    # default `claude mcp add` scope is local = this project only, which is what we want.
    # remove first so re-running scope-add.sh --claude is idempotent
    ( cd "$ABS" && claude mcp remove graphify >/dev/null 2>&1 || true
      claude mcp add --transport stdio graphify -- \
        graphify-mcp "$GRAPHS/$NAME/graph.json" ) \
      && info "MCP server 'graphify' added in $ABS (local scope)"
  else
    warn "claude CLI not found — add the MCP server yourself:"
    echo "    cd $ABS && claude mcp add --transport stdio graphify -- graphify-mcp $GRAPHS/$NAME/graph.json"
  fi
fi
