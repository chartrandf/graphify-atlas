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
  out="$(graph_dir "$name")"

  if [[ ! -d "$path" ]]; then
    warn "$name: $path is gone, skipping"
    failed+=("$name")
    continue
  fi

  info "$name  ($mode)  $path"
  mkdir -p "$out"

  # GRAPHIFY_OUT, not --out: see the note in lib.sh. --out leaves a cache behind
  # inside the scanned project. Set per command so it never leaks past the loop.
  args=(extract "$path")
  [[ "$mode" == "code-only" ]] && args+=(--code-only)

  if ! GRAPHIFY_OUT="$out" graphify "${args[@]}"; then
    warn "$name: extract failed"
    failed+=("$name")
    continue
  fi

  # extract writes graph.json and stops; graph.html and GRAPH_REPORT.md come from
  # clustering. --no-label on code-only: naming communities is an LLM call, and
  # code-only means nothing leaves this machine.
  cargs=(cluster-only "$path")
  [[ "$mode" == "code-only" ]] && cargs+=(--no-label)
  GRAPHIFY_OUT="$out" graphify "${cargs[@]}" >/dev/null \
    || warn "$name: graph built, but clustering/report failed"

  # Re-register so the name always points at the current graph.
  graphify global remove "$name" >/dev/null 2>&1 || true
  graphify global add "$(graph_json "$name")" --as "$name" >/dev/null \
    || warn "$name: graph built, but 'graphify global add' failed"
done

echo
if [[ ${#failed[@]} -gt 0 ]]; then
  warn "failed: ${failed[*]}"
  exit 1
fi
info "done — bin/scope-list.sh to review"
