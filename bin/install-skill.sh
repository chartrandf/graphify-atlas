#!/usr/bin/env bash
#
# Install this repo's Claude Code skill so agents ask the graph before grepping.
#
#   bin/install-skill.sh             symlink into ~/.claude/skills/
#   bin/install-skill.sh --dir DIR   somewhere else (a project's .claude/skills)
#   bin/install-skill.sh --copy      copy instead of symlink
#   bin/install-skill.sh --force     replace an existing real directory (backed up)
#   bin/install-skill.sh --remove
#
# A SYMLINK by default, matching bin/install-cli.sh: the skill is versioned in
# this repo, and edits are live with nothing to reinstall. Use --copy if you want
# a frozen snapshot that survives this repo moving or being deleted.
#
# The skill shells out to `gatlas`, so run bin/install-cli.sh too.
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

NAME="graphify-atlas"
SRC="$ROOT/skills/$NAME"
DIR="$HOME/.claude/skills"
COPY=0 FORCE=0 REMOVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)    DIR="${2:?--dir needs a path}"; shift 2 ;;
    --copy)   COPY=1; shift ;;
    --force)  FORCE=1; shift ;;
    --remove) REMOVE=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

DEST="$DIR/$NAME"

if [[ $REMOVE -eq 1 ]]; then
  if [[ -L "$DEST" ]]; then
    rm "$DEST"; info "removed symlink $DEST"
  elif [[ -d "$DEST" ]]; then
    [[ $FORCE -eq 1 ]] || die "$DEST is a real directory — rerun with --force to delete it"
    rm -rf "$DEST"; info "removed $DEST"
  else
    info "nothing installed at $DEST"
  fi
  exit 0
fi

[[ -f "$SRC/SKILL.md" ]] || die "missing $SRC/SKILL.md"
mkdir -p "$DIR"

# Never silently destroy a skill someone edited in place.
if [[ -e "$DEST" && ! -L "$DEST" ]]; then
  if [[ $FORCE -eq 1 ]]; then
    # Back up OUTSIDE the skills dir: anything left inside it is loaded as a
    # second, duplicate skill with the same description.
    bakdir="$(dirname "$DIR")/skills-backup"
    mkdir -p "$bakdir"
    bak="$bakdir/$NAME.$(date +%Y%m%d%H%M%S)"
    mv "$DEST" "$bak"
    warn "existing directory moved to $bak"
  else
    die "$DEST already exists and is not a symlink.
    Compare it first:  diff -ru '$DEST' '$SRC'
    Then rerun with --force (the old one is backed up), or --copy --force."
  fi
fi

if [[ $COPY -eq 1 ]]; then
  rm -rf "$DEST"
  cp -R "$SRC" "$DEST"
  info "copied $SRC -> $DEST"
  warn "a copy does not track this repo — rerun after changing the skill"
else
  ln -sfn "$SRC" "$DEST"
  info "linked $DEST -> $SRC"
fi

command -v gatlas >/dev/null 2>&1 \
  || warn "gatlas is not on PATH — the skill needs it: $ROOT/bin/install-cli.sh"

echo
echo "Restart Claude Code (or start a new session) to pick the skill up."
