#!/usr/bin/env bash
#
# (Re)build graphs for tracked projects. Output goes to graphs/<project>/<slot>/
# in this repo — never into the project itself.
#
#   bin/refresh.sh                    every tracked project, primary checkout
#   bin/refresh.sh api portal         just these
#   bin/refresh.sh --all-worktrees    every live worktree of each target too
#
# A "slot" is one worktree: _primary for the main checkout, the slugified
# directory name for a linked worktree. Rebuilding the slot you are standing in
# is bin/graph.sh's job — it also checks freshness first.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_graphify

ALL_WT=0
targets=()
for a in "$@"; do
  case "$a" in
    --all-worktrees) ALL_WT=1 ;;
    -*) die "unknown option: $a" ;;
    *)  targets+=("$a") ;;
  esac
done

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

  if [[ ! -d "$path" ]]; then
    warn "$name: $path is gone, skipping"
    failed+=("$name")
    continue
  fi

  # worktree root -> slot. The tracked path is the primary checkout, but resolve
  # it rather than assuming: scope.tsv may well point at a worktree.
  worktrees=("$path")
  if [[ $ALL_WT -eq 1 ]]; then
    # shellcheck disable=SC2207
    worktrees=($(git -C "$path" worktree list --porcelain 2>/dev/null \
      | awk '/^worktree /{print $2}'))
  fi

  for wt in "${worktrees[@]}"; do
    [[ -d "$wt" ]] || { warn "$name: $wt is gone, skipping"; continue; }
    slot="$(resolve_slot "$wt" | cut -f2)" || { warn "$name: cannot resolve $wt"; continue; }
    out="$(slot_dir "$name" "$slot")"

    info "$name/$slot  ($mode, $(worktree_label "$wt"))  $wt"
    if ! slot_lock "$out" 60; then
      warn "$name/$slot: busy, skipping"
      failed+=("$name/$slot")
      continue
    fi
    if build_slot "$name" "$slot" "$wt" "$mode"; then
      slot_unlock "$out"
    else
      slot_unlock "$out"
      warn "$name/$slot: build failed"
      failed+=("$name/$slot")
    fi
  done
done

echo
if [[ ${#failed[@]} -gt 0 ]]; then
  warn "failed: ${failed[*]}"
  exit 1
fi
info "done — bin/scope-list.sh to review"
