#!/usr/bin/env bash
#
# Drop a project from scope.
#
#   bin/scope-remove.sh <name> [--purge]
#
#   --purge   also delete graphs/<name>/
#
# The tracked project itself is never touched.
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
