#!/usr/bin/env bash
# Shared helpers for the scope scripts. Sourced, never executed directly.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="$ROOT/scope.tsv"
GRAPHS="$ROOT/graphs"

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ~/foo <-> /Users/me/foo, so scope.tsv stays portable across machines
tildify()   { case "$1" in "$HOME"/*) printf '~%s\n' "${1#"$HOME"}" ;; *) printf '%s\n' "$1" ;; esac; }
untildify() { case "$1" in "~/"*)     printf '%s/%s\n' "$HOME" "${1#\~/}" ;; *) printf '%s\n' "$1" ;; esac; }

# Data rows only: strip comments and blanks.
scope_rows() { awk -F'\t' '!/^#/ && NF' "$SCOPE"; }
scope_names() { scope_rows | cut -f1; }

# name -> "path<TAB>mode", empty if unknown
scope_lookup() { scope_rows | awk -F'\t' -v n="$1" '$1 == n { print $2 "\t" $3; exit }'; }

scope_path() { untildify "$(scope_lookup "$1" | cut -f1)"; }
scope_mode() { scope_lookup "$1" | cut -f2; }

# Where graphify actually puts things. `graphify extract --out DIR` writes into
# DIR/graphify-out/ — it appends the dir itself — so the target we pass and the
# files we read back are NOT the same path. One source of truth for both.
graph_target() { printf '%s/%s\n' "$GRAPHS" "$1"; }          # what --out receives
graph_out()    { printf '%s/%s/graphify-out\n' "$GRAPHS" "$1"; }
graph_json()   { printf '%s/%s/graphify-out/graph.json\n' "$GRAPHS" "$1"; }

# Lowercase, non-alnum collapsed to a single dash. Used to derive a name from a folder.
slugify() {
  printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//'
}

need_graphify() {
  command -v graphify >/dev/null 2>&1 || die "graphify is not on PATH — run: $ROOT/bin/install.sh"
}
