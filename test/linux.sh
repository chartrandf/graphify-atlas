#!/usr/bin/env bash
#
# Run the whole install + workflow on real Linux, in a container.
#
#   test/linux.sh            python:3.12-slim
#   test/linux.sh IMAGE      e.g. debian:12, ubuntu:24.04
#
# Needs docker running. Takes a couple of minutes on a cold image pull.
#
# SAFETY: this repo is mounted READ-ONLY and copied inside the container before
# anything runs. The suite deletes scope.tsv, prunes graphs and runs the
# uninstaller — with a writable mount that wipes your real scope and graphs.
# Do not "fix" the :ro.
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
source "$(cd -P "$(dirname "$_s")/../bin" && pwd)/lib.sh"

case "${1:-}" in
  -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
esac

IMAGE="${1:-python:3.12-slim}"
command -v docker >/dev/null 2>&1 || die "docker is not installed"
docker info >/dev/null 2>&1 || die "the docker daemon is not running"

info "testing on $IMAGE (this repo is mounted read-only and copied inside)"

suite="$(mktemp)"
trap 'rm -f "$suite"' EXIT
cat > "$suite" <<'SUITE'
set -e
fail=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=1; }
is()   { [ "$2" = "$3" ] && ok "$1" || { bad "$1 (got '$2', want '$3')"; }; }

export PATH="$PATH:/root/.local/bin"
# Work on a COPY. The read-only mount is the backstop, this is the intent.
cp -r /atlas-ro /atlas && cd /atlas
rm -rf graphs/* scope.tsv

echo "platform: $(uname -sm), $(bash --version | head -1)"
echo

rm -f scope.tsv
bin/scope-list.sh >/dev/null 2>&1
[ -f scope.tsv ] && ok "scope.tsv self-creates" || bad "scope.tsv self-creates"

mkdir -p /work/proj/src
printf 'def connect():\n    return "c"\n' > /work/proj/src/db.py
printf 'from db import connect\n\ndef login(u):\n    return connect()\n' > /work/proj/src/auth.py
cd /work/proj && git init -q && git add -A
git -c user.email=t@t -c user.name=t commit -qm init >/dev/null && git branch -M main
git worktree add -q --detach /work/wt main
cd /atlas

bin/install-cli.sh >/dev/null 2>&1
[ -L /root/.local/bin/gatlas ] && ok "gatlas symlink installed" || bad "gatlas symlink installed"
command -v gatlas >/dev/null && ok "gatlas runs through the symlink" || bad "gatlas runs through the symlink"

bin/scope-add.sh /work/proj --name demo >/dev/null 2>&1
[ -f /atlas/graphs/demo/_primary/graph.json ] && ok "scope-add builds _primary" || bad "scope-add builds _primary"

[ -z "$(ls -A /work/proj/graphify-out 2>/dev/null)" ] && ok "scanned project not polluted" || bad "scanned project not polluted"

is "primary resolves to _primary" "$(cd /work/proj && gatlas status | awk '/^slot/{print $2}')" "_primary"
is "worktree resolves to its slot" "$(cd /work/wt && gatlas status | awk '/^slot/{print $2}')" "wt"
is "subdir resolves too"           "$(cd /work/proj/src && gatlas status | awk '/^slot/{print $2}')" "_primary"
is "untracked dir exits 2"         "$(cd /tmp && gatlas status >/dev/null 2>&1; echo $?)" "2"

is "ensure stdout is one path" "$(cd /work/wt && gatlas ensure 2>/dev/null | wc -l | tr -d ' ')" "1"

cd /work/proj
is "fresh after build" "$(gatlas status | awk '/^state/{print $2}')" "current"
echo '# x' >> src/db.py && git -c user.email=t@t -c user.name=t commit -aqm change >/dev/null
is "stale after commit" "$(gatlas status | awk '/^state/{print $2}')" "stale"
gatlas ensure >/dev/null 2>&1
is "current after ensure" "$(gatlas status | awk '/^state/{print $2}')" "current"

echo '# y' >> src/db.py && git -c user.email=t@t -c user.name=t commit -aqm race >/dev/null
rm -f /tmp/e.*
for i in 1 2 3 4; do ( gatlas ensure >/dev/null 2>/tmp/e.$i ) & done; wait
is "4 agents -> 1 rebuild" "$(cat /tmp/e.* | grep -c rebuilding || true)" "1"

cd /atlas
bin/install-skill.sh </dev/null >/dev/null 2>&1
[ -L /root/.claude/skills/graphify-atlas ] && ok "skill installs non-interactively" || bad "skill installs non-interactively"

cd /work/proj && git worktree remove --force /work/wt
cd /atlas && bin/graph-gc.sh --prune >/dev/null 2>&1
[ ! -d /atlas/graphs/demo/wt ] && ok "gc drops the orphaned slot" || bad "gc drops the orphaned slot"
[ -d /atlas/graphs/demo/_primary ] && ok "gc keeps the live slot" || bad "gc keeps the live slot"

bin/uninstall.sh >/dev/null 2>&1
[ -f /atlas/scope.tsv ] && ok "uninstall dry run changes nothing" || bad "uninstall dry run changes nothing"
bin/uninstall.sh --yes >/dev/null 2>&1
[ ! -e /root/.claude/skills/graphify-atlas ] && ok "uninstall removes the skill" || bad "uninstall removes the skill"
[ ! -f /atlas/scope.tsv ] && ok "uninstall removes scope.tsv" || bad "uninstall removes scope.tsv"
[ -f /atlas/bin/graph.sh ] && ok "uninstall keeps repo files" || bad "uninstall keeps repo files"

echo
[ $fail -eq 0 ] && echo "ALL PASSED" || { echo "FAILURES ABOVE"; exit 1; }
SUITE

docker run --rm \
  -v "$ROOT":/atlas-ro:ro \
  -v "$suite":/suite.sh:ro \
  -e HOME=/root \
  "$IMAGE" bash -c '
    set -e
    # Plain distro images ship neither git nor python.
    if command -v apt-get >/dev/null; then
      apt-get -qq update >/dev/null 2>&1
      apt-get -qq install -y git python3 python3-pip >/dev/null 2>&1
    elif command -v apk >/dev/null; then
      apk add --quiet git python3 py3-pip bash >/dev/null 2>&1
    fi
    command -v python3 >/dev/null || { echo "no python3 and no known package manager"; exit 1; }
    # Debian 12+ marks the system python externally-managed (PEP 668).
    python3 -m pip install -q --root-user-action=ignore graphifyy >/dev/null 2>&1 \
      || python3 -m pip install -q --break-system-packages graphifyy >/dev/null 2>&1 \
      || { echo "could not install graphifyy"; exit 1; }
    command -v graphify >/dev/null || export PATH="$PATH:/usr/local/bin:/root/.local/bin"
    bash /suite.sh'
