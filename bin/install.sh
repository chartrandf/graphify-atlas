#!/usr/bin/env bash
#
# Install the graphify CLI on this machine. Idempotent.
#
#   bin/install.sh              install (or report an existing install)
#   bin/install.sh --upgrade    upgrade in place
#
# Extras default to "mcp". Override: GRAPHIFY_EXTRAS="mcp,watch" bin/install.sh
#
# The PyPI package is `graphifyy` (two y's) — the docs warn about lookalike packages.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

UPGRADE=0
[[ "${1:-}" == "--upgrade" ]] && UPGRADE=1

EXTRAS="${GRAPHIFY_EXTRAS:-mcp}"
PKG="graphifyy"
[[ -n "$EXTRAS" ]] && PKG="graphifyy[$EXTRAS]"

# graphify needs Python 3.10+; uv provisions its own interpreter, pipx does not.
if command -v uv >/dev/null 2>&1; then
  MGR=uv
elif command -v pipx >/dev/null 2>&1; then
  MGR=pipx
else
  die "need uv or pipx. Install uv:  curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

if command -v graphify >/dev/null 2>&1 && [[ $UPGRADE -eq 0 ]]; then
  info "graphify already installed: $(graphify --version 2>&1 | head -1)"
  info "to upgrade: bin/install.sh --upgrade"
  exit 0
fi

if [[ $UPGRADE -eq 1 ]]; then
  info "upgrading $PKG via $MGR"
  case $MGR in
    uv)   uv tool upgrade graphifyy ;;
    pipx) pipx upgrade graphifyy ;;
  esac
else
  info "installing $PKG via $MGR"
  case $MGR in
    uv)   uv tool install "$PKG" ;;
    pipx) pipx install "$PKG" ;;
  esac
fi

command -v graphify >/dev/null 2>&1 \
  || die "install finished but graphify is not on PATH — check your shell PATH (uv tool dir, or ~/.local/bin)"

info "ok: $(graphify --version 2>&1 | head -1)"
echo
echo "Next: track a project"
echo "  bin/scope-add.sh ~/Projects/some-repo"
