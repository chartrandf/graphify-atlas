#!/usr/bin/env bash
#
# (Re)build the graph for tracked projects. Output goes to graphs/<name>/ in this
# repo — never into the project itself — and is registered with graphify's own
# global registry so `graphify global path` can cross project boundaries.
#
#   bin/refresh.sh              all tracked projects
#   bin/refresh.sh api portal   just these
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_graphify

targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
  # shellcheck disable=SC2207
  targets=($(scope_names))
  [[ ${#targets[@]} -eq 0 ]] && die "nothing tracked yet — bin/scope-add.sh <path>"
fi

failed=()
for name in "${targets[@]}"; do
  row="$(scope_lookup "$name")"
  [[ -z "$row" ]] && { warn "$name: not tracked, skipping"; failed+=("$name"); continue; }

  path="$(untildify "$(cut -f1 <<<"$row")")"
  mode="$(cut -f2 <<<"$row")"
  out="$GRAPHS/$name"

  if [[ ! -d "$path" ]]; then
    warn "$name: $path is gone, skipping"
    failed+=("$name")
    continue
  fi

  info "$name  ($mode)  $path"
  mkdir -p "$out"

  args=(extract "$path" --out "$out")
  [[ "$mode" == "code-only" ]] && args+=(--code-only)

  if ! graphify "${args[@]}"; then
    warn "$name: extract failed"
    failed+=("$name")
    continue
  fi

  # Re-register so the name always points at the current graph.
  graphify global remove "$name" >/dev/null 2>&1 || true
  graphify global add "$out/graph.json" --as "$name" >/dev/null \
    || warn "$name: graph built, but 'graphify global add' failed"
done

echo
if [[ ${#failed[@]} -gt 0 ]]; then
  warn "failed: ${failed[*]}"
  exit 1
fi
info "done — bin/scope-list.sh to review"
