#!/usr/bin/env bash
#
# Drop a project from scope.
#
#   bin/scope-remove.sh <name> [--purge]
#
#   --purge   also delete graphs/<name>/
#
# The tracked project itself is never touched. If it was wired with --claude,
# undo that from the project:  graphify uninstall --project --platform claude
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NAME="${1:-}"; PURGE=0
[[ "${2:-}" == "--purge" ]] && PURGE=1
[[ -n "$NAME" ]] || die "usage: bin/scope-remove.sh <name> [--purge]"
[[ -n "$(scope_lookup "$NAME")" ]] || die "not tracked: $NAME"

tmp="$(mktemp)"
awk -F'\t' -v n="$NAME" '/^#/ || $1 != n' "$SCOPE" > "$tmp"
mv "$tmp" "$SCOPE"
info "untracked $NAME"

if command -v graphify >/dev/null 2>&1; then
  graphify global remove "$NAME" >/dev/null 2>&1 && info "removed from graphify global registry" || true
fi

if [[ $PURGE -eq 1 && -d "$GRAPHS/$NAME" ]]; then
  rm -rf "${GRAPHS:?}/$NAME"
  info "deleted graphs/$NAME"
elif [[ -d "$GRAPHS/$NAME" ]]; then
  info "graphs/$NAME kept — delete it with --purge"
fi
