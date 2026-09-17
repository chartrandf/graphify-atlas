#!/usr/bin/env bash
#
# Undo everything this repo installed, and clear the state it generated.
#
#   bin/uninstall.sh          DRY RUN — list exactly what would go
#   bin/uninstall.sh --yes    actually do it
#   bin/uninstall.sh --yes --purge-cli   also uninstall the graphifyy package
#   bin/uninstall.sh --yes --keep-scope  keep scope.tsv (the project list)
#
# Removes, in order:
#   1. the `gatlas` symlink on PATH
#   2. the Claude Code skill, and any backup install-skill.sh set aside
#   3. every built graph under graphs/, and their entries in graphify's own
#      global registry
#   4. scope.tsv — the list of tracked projects
#   5. with --purge-cli, the graphifyy CLI itself (uv or pipx)
#
# It NEVER touches the tracked projects it mapped, and never deletes this repo's
# own committed files. Delete the clone yourself afterwards if you want it gone.
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

GO=0 PURGE_CLI=0 KEEP_SCOPE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)     GO=1; shift ;;
    --purge-cli)  PURGE_CLI=1; shift ;;
    --keep-scope) KEEP_SCOPE=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

act() { # <description> <command...>
  local what="$1"; shift
  if [[ $GO -eq 1 ]]; then
    "$@" >/dev/null 2>&1 || true
    info "removed $what"
  else
    echo "  would remove  $what"
  fi
}

[[ $GO -eq 1 ]] || {
  info "DRY RUN — nothing will be changed. Rerun with --yes to apply."
  echo
}

# 1. the CLI symlink
for d in "$HOME/.local/bin" "$HOME/bin" /usr/local/bin; do
  [[ -L "$d/gatlas" ]] && act "$d/gatlas" rm -f "$d/gatlas"
done

# 2. the skill, plus backups install-skill.sh may have left
for d in "$HOME/.claude/skills"; do
  [[ -e "$d/graphify-atlas" ]] && act "$d/graphify-atlas" rm -rf "$d/graphify-atlas"
done
for b in "$HOME/.claude/skills-backup"/graphify-atlas.* "$HOME/.claude/skills"/graphify-atlas.bak.*; do
  [[ -e "$b" ]] && act "$b" rm -rf "$b"
done

# 3. built graphs + graphify's own registry entries
if command -v graphify >/dev/null 2>&1; then
  while read -r name; do
    [[ -n "$name" ]] || continue
    act "graphify global entry '$name'" graphify global remove "$name"
  done < <(scope_names 2>/dev/null || true)
fi

shopt -s nullglob
for d in "$GRAPHS"/*/; do
  size="$(du -sh "$d" 2>/dev/null | cut -f1 | tr -d ' ')"
  act "graphs/$(basename "$d")/  (${size:-?})" rm -rf "$d"
done
shopt -u nullglob

# 4. the project list
if [[ $KEEP_SCOPE -eq 0 && -f "$SCOPE" ]]; then
  n="$(scope_rows 2>/dev/null | wc -l | tr -d ' ')"
  act "scope.tsv  ($n tracked project(s))" rm -f "$SCOPE"
fi

# 5. the CLI package itself
if [[ $PURGE_CLI -eq 1 ]]; then
  if command -v uv >/dev/null 2>&1 && uv tool list 2>/dev/null | grep -q '^graphifyy'; then
    act "graphifyy (uv tool)" uv tool uninstall graphifyy
  elif command -v pipx >/dev/null 2>&1 && pipx list --short 2>/dev/null | grep -q graphifyy; then
    act "graphifyy (pipx)" pipx uninstall graphifyy
  fi
fi

echo
if [[ $GO -eq 1 ]]; then
  info "done. This repo's own files are untouched — delete the clone to finish."
  [[ $PURGE_CLI -eq 0 ]] && echo "  the graphifyy CLI is still installed (--purge-cli removes it)"
else
  echo "  nothing changed. Rerun with --yes to apply."
fi
