#!/usr/bin/env bash
# Shared helpers for the scope scripts. Sourced, never executed directly.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="$ROOT/scope.tsv"
GRAPHS="$ROOT/graphs"

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# scope.tsv is gitignored (it names local project paths and this repo is public),
# so it is absent on a fresh clone — and on any checkout of a commit from before
# it was untracked. Create it from the example instead of failing.
ensure_scope() {
  [[ -f "$SCOPE" ]] && return 0
  if [[ -f "$ROOT/scope.tsv.example" ]]; then
    cp "$ROOT/scope.tsv.example" "$SCOPE"
  else
    printf '# Projects tracked by this knowledge base.\n' > "$SCOPE"
    printf '# Managed by bin/scope-add.sh / bin/scope-remove.sh — edit by hand only if you know why.\n' >> "$SCOPE"
    printf '# name\tpath\tmode\n' >> "$SCOPE"
  fi
}
ensure_scope

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

# Where graphify puts things. Always drive it with an absolute GRAPHIFY_OUT,
# never `extract --out DIR`:
#   --out redirects graph.json but STILL writes a stat-index cache into
#   <scanned project>/graphify-out/ — a write into a tracked project, which is
#   exactly what this repo exists to prevent. It also nests everything one level
#   deeper (DIR/graphify-out/).
# An absolute GRAPHIFY_OUT redirects the graph, the report and every cache, and
# leaves the scanned project untouched.
graph_dir()  { printf '%s/%s\n' "$GRAPHS" "$1"; }
graph_json() { printf '%s/%s/graph.json\n' "$GRAPHS" "$1"; }

# ── Worktree resolution ───────────────────────────────────────────────────────
# Graphify graphs a DIRECTORY, never a branch, so "the graph for this branch"
# can only mean "the graph for this worktree". Every worktree of a repo shares
# one --git-common-dir, which is what identifies the project; --show-toplevel
# then identifies the individual worktree. A detached worktree reports its
# branch as the literal "HEAD", so the branch name is never a usable key.

# Absolute --git-common-dir for the repo containing <dir>. Identical from the
# primary checkout and from every linked worktree.
git_common_dir() {
  local d="${1:-$PWD}" g
  g="$(git -C "$d" rev-parse --git-common-dir 2>/dev/null)" || return 1
  [[ -n "$g" ]] || return 1
  # git may answer relative (".git"); resolve it against the dir we asked about
  ( cd "$d" && cd "$g" 2>/dev/null && pwd )
}

worktree_root() { git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null; }

# The primary checkout is the one whose git-dir IS the common dir.
is_primary_worktree() {
  local d="${1:-$PWD}" g c
  g="$(git -C "$d" rev-parse --git-dir 2>/dev/null)" || return 1
  g="$( cd "$d" && cd "$g" 2>/dev/null && pwd )" || return 1
  c="$(git_common_dir "$d")" || return 1
  [[ "$g" == "$c" ]]
}

# Tracked project owning <dir>, or non-zero when it is not in scope.
project_for_dir() {
  local dir="${1:-$PWD}" cdir name path p c
  cdir="$(git_common_dir "$dir")" || return 1
  while IFS=$'\t' read -r name path _; do
    [[ -n "$name" ]] || continue
    p="$(untildify "$path")"
    [[ -d "$p" ]] || continue
    c="$(git_common_dir "$p")" || continue
    if [[ "$c" == "$cdir" ]]; then printf '%s\n' "$name"; return 0; fi
  done < <(scope_rows)
  return 1
}

# Stable short digest of a path. cksum is POSIX; shasum/md5 are not guaranteed.
path_hash() { printf '%s' "$1" | cksum | cut -d' ' -f1; }

# project<TAB>slot<TAB>worktree_root for <dir>, non-zero if not in a tracked project.
# The slot names the worktree: "_primary" for the main checkout (slugify never
# emits a leading underscore, so a linked worktree can never collide with it),
# otherwise the slugified directory name, disambiguated by a path digest only
# when a different worktree already owns that slug.
resolve_slot() {
  local dir="${1:-$PWD}" project root slot claimed
  project="$(project_for_dir "$dir")" || return 1
  root="$(worktree_root "$dir")" || return 1
  if is_primary_worktree "$dir"; then
    slot="_primary"
  else
    slot="$(slugify "$(basename "$root")")"
    [[ -n "$slot" ]] || slot="worktree"
    claimed="$GRAPHS/$project/$slot/.graphify_root"
    if [[ -f "$claimed" && "$(cat "$claimed")" != "$root" ]]; then
      slot="$slot-$(path_hash "$root")"
    fi
  fi
  printf '%s\t%s\t%s\n' "$project" "$slot" "$root"
}

slot_dir()  { printf '%s/%s/%s\n' "$GRAPHS" "$1" "$2"; }   # what GRAPHIFY_OUT gets
slot_json() { printf '%s/%s/%s/graph.json\n' "$GRAPHS" "$1" "$2"; }
slot_root() { printf '%s/%s/%s/.graphify_root\n' "$GRAPHS" "$1" "$2"; }

# ── Freshness ─────────────────────────────────────────────────────────────────
# graph.json carries a top-level "built_at_commit", stamped by graphify from the
# analysed repo's HEAD. It is written last, so the tail is enough — a full grep
# of a 27 MB graph costs 0.3s, the tail costs nothing. The grep stays as a
# fallback in case that ordering ever changes.
graph_built_commit() {
  local g="$1" sha
  [[ -f "$g" ]] || return 1
  sha="$(tail -c 4096 "$g" \
    | sed -n 's/.*"built_at_commit"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,\}\)".*/\1/p' | tail -1)"
  if [[ -z "$sha" ]]; then
    sha="$(grep -o -m1 '"built_at_commit"[[:space:]]*:[[:space:]]*"[0-9a-f]\{7,\}"' "$g" 2>/dev/null \
      | grep -o '[0-9a-f]\{7,\}')"
  fi
  [[ -n "$sha" ]] || return 1
  printf '%s\n' "$sha"
}

# Fresh = graph exists, worktree is clean, and it was built from the current HEAD.
# A dirty worktree is never fresh: a sha cannot describe uncommitted work.
graph_is_fresh() {
  local g="$1" wt="$2" built head
  [[ -f "$g" ]] || return 1
  [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]] && return 1
  built="$(graph_built_commit "$g")" || return 1
  head="$(git -C "$wt" rev-parse HEAD 2>/dev/null)" || return 1
  [[ "$built" == "$head" ]]
}

# Lowercase, non-alnum collapsed to a single dash. Used to derive a name from a folder.
slugify() {
  printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//'
}

need_graphify() {
  command -v graphify >/dev/null 2>&1 || die "graphify is not on PATH — run: $ROOT/bin/install.sh"
}
