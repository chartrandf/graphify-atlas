#!/usr/bin/env bash
#
# Put `gatlas` on your PATH so agents can reach the graph from inside any
# project, without knowing where this repo lives.
#
#   bin/install-cli.sh             symlink into ~/.local/bin
#   bin/install-cli.sh --dir DIR   somewhere else on your PATH
#   bin/install-cli.sh --remove
#
# It is a SYMLINK, not a copy: edits in this repo take effect on the next call,
# with nothing to reinstall. `gatlas` fronts every command —
# ensure / query / status / path / list / gc / refresh.
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

DIR="$HOME/.local/bin"
REMOVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)    DIR="${2:?--dir needs a path}"; shift 2 ;;
    --remove) REMOVE=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

LINK="$DIR/gatlas"

if [[ $REMOVE -eq 1 ]]; then
  if [[ -L "$LINK" ]]; then
    rm "$LINK"; info "removed $LINK"
  else
    info "nothing to remove at $LINK"
  fi
  exit 0
fi

mkdir -p "$DIR"

# Never clobber a real file that happens to sit there.
if [[ -e "$LINK" && ! -L "$LINK" ]]; then
  die "$LINK exists and is not a symlink — move it aside first"
fi

ln -sfn "$ROOT/bin/graph.sh" "$LINK"
info "linked $LINK -> $ROOT/bin/graph.sh"

case ":$PATH:" in
  *":$DIR:"*) info "ok: $DIR is on your PATH" ;;
  *) warn "$DIR is not on your PATH — add it:"
     echo "    echo 'export PATH=\"\$PATH:$DIR\"' >> ~/.zshrc" ;;
esac

echo
echo "Try it from inside a tracked project:"
echo "  gatlas status"
echo "  gatlas query \"how does auth reach the database?\""
