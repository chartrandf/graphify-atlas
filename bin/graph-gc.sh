#!/usr/bin/env bash
#
# Drop graph slots whose worktree no longer exists. A slot is ~60 MB and
# worktrees turn over fast, so this is worth running when you close one.
#
#   bin/graph-gc.sh            report what would go
#   bin/graph-gc.sh --prune    actually delete it
#   bin/graph-gc.sh --prune --quiet
#
# A slot records its source in .graphify_root. If that path is gone, so is the
# reason to keep the graph. Slots of projects no longer in scope.tsv go too.
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

PRUNE=0 QUIET=0
for a in "$@"; do
  case "$a" in
    --prune) PRUNE=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) die "unknown option: $a" ;;
  esac
done

say() { [[ $QUIET -eq 1 ]] || info "$@"; }

dead=0 freed=0
for projdir in "$GRAPHS"/*/; do
  [[ -d "$projdir" ]] || continue
  project="$(basename "$projdir")"
  tracked=1
  [[ -n "$(scope_lookup "$project")" ]] || tracked=0

  for slotdir in "$projdir"*/; do
    [[ -d "$slotdir" ]] || continue
    slot="$(basename "$slotdir")"
    # Only ever consider real slots. A stray directory (an interrupted build's
    # cache/, anything hand-made) is left alone — deleting it is not GC's call.
    if ! is_slot_dir "$slotdir"; then
      say "$project/$slot: not a graph slot, leaving it"
      continue
    fi
    root="$(cat "$slotdir/.graphify_root" 2>/dev/null || true)"

    reason=""
    if [[ $tracked -eq 0 ]]; then
      reason="project no longer in scope"
    elif [[ -z "$root" ]]; then
      reason="no .graphify_root — cannot tell what it came from"
    elif [[ ! -d "$root" ]]; then
      reason="worktree gone: $root"
    fi
    [[ -z "$reason" ]] && continue

    # A slot mid-build is not garbage.
    if [[ -d "$slotdir/.lock" ]]; then
      say "$project/$slot: locked, skipping"
      continue
    fi

    dead=$((dead + 1))
    size="$(du -sk "$slotdir" 2>/dev/null | cut -f1)"
    freed=$((freed + ${size:-0}))
    if [[ $PRUNE -eq 1 ]]; then
      rm -rf "${slotdir:?}"
      say "removed $project/$slot — $reason"
    else
      say "would remove $project/$slot — $reason"
    fi
  done

  # Drop the project dir once its last slot is gone.
  [[ $PRUNE -eq 1 && -d "$projdir" ]] && rmdir "$projdir" 2>/dev/null || true
done

if [[ $dead -eq 0 ]]; then
  say "nothing to collect"
elif [[ $PRUNE -eq 1 ]]; then
  say "removed $dead slot(s), freed $((freed / 1024)) MB"
else
  say "$dead slot(s) reclaimable, $((freed / 1024)) MB — rerun with --prune"
fi
