# graphify-atlas

> **Scope it, graph it, keep it out of the repo.**

Central [Graphify](https://docs.graphify.com) knowledge base for selected local projects.

One folder holds the scope manifest and every project's graph. Nothing is written into
the tracked projects unless you ask for it, and no analysis output is ever committed.

```
scope.tsv          which projects are tracked   (gitignored — personal)
scope.tsv.example  header-only starter          (committed)
graphs/<project>/<slot>/   one graph per worktree   (gitignored)
bin/               the scripts
templates/         .graphifyignore starter
AGENTS.md          contract for coding agents (CLAUDE.md points here)
AI_TASKS/          notes and plans   (ignored by your global ~/.gitignore — see .gitignore)
```

## Setup

```bash
bin/install.sh                      # installs the graphify CLI (uv, or pipx)
bin/install-cli.sh                  # puts `gatlas` on your PATH
bin/scope-add.sh ~/Projects/my-repo # track a project and build its graph
gatlas list                         # see what is tracked
```

That is the whole setup. Both installers are idempotent; re-run them any time.

### `gatlas`

`bin/install-cli.sh` symlinks `gatlas` into `~/.local/bin` (override with `--dir`, undo with
`--remove`). It is a **symlink to `bin/graph.sh`**, not a copy, so changes you make in this repo
take effect on the next call — there is nothing to reinstall.

One command fronts everything, and it works from inside any tracked project — or any
subdirectory of one — without knowing where this repo lives:

```bash
gatlas query "<question>"   # resolve this worktree, rebuild if stale, answer
gatlas status               # project, slot, branch, built-from sha, current or stale
gatlas ensure               # prints the graph path (rebuilding first if needed)
gatlas list                 # every tracked project and worktree slot
gatlas gc [--prune]         # drop slots whose worktree is gone
gatlas refresh <name> [--all-worktrees]
```

Exit codes: `0` ok, `2` not a tracked project, `1` error. Stdout from `ensure` is the graph
path and nothing else — progress goes to stderr, so it is safe to use in a script.

### Claude Code

`~/.claude/skills/graphify-atlas/SKILL.md` teaches agents to ask the graph before grepping,
and to fall back to search — saying so — when a repo is not tracked. It shells out to `gatlas`,
so it needs `bin/install-cli.sh` to have run.

## Scope

A project is in scope only because you added it. `graphify extract` reads the folder you
point it at and nothing else, so untracked repos are never looked at.

```bash
bin/scope-add.sh <path> [options]

  --name NAME        registry name (default: slug of the folder name)
  --semantic         semantic extraction too — needs an API key, sends code to a
                     model backend. Default is --code-only: structural parsing
                     locally, nothing leaves the machine.
  --ignore-template  drop templates/graphifyignore into the project
  --no-extract       record it now, build later

bin/scope-remove.sh <name> [--purge]   # --purge also deletes graphs/<name>
gatlas refresh [name ...] [--all-worktrees]   # rebuild; no args = everything
```

`--code-only` is the default on purpose — it is the safe mode for client and employer
code. Opt into `--semantic` per project, knowingly.

`--ignore-template` is the only flag that writes into the tracked project. Everything
else here is read-only toward the projects it maps — which is why the scripts drive
graphify through an absolute `GRAPHIFY_OUT` rather than `extract --out`: `--out` still
leaves a cache directory behind inside the project it scanned.

Never run `graphify install` in any form — the global form installs instructions and
PreToolUse hooks that fire in *every* project, which is exactly what this repo exists to
avoid, and the `--project` form scatters the same wiring through each tracked repo.

## Querying

From inside a tracked project. This resolves the worktree you are standing in and rebuilds
the graph first if it no longer matches your HEAD, so the answer always describes the code
in front of you:

```bash
cd ~/Projects/my-repo
gatlas query "how does authentication reach the database?"
gatlas status
```

Drilling into one node — `gatlas ensure` hands you a path that is guaranteed current:

```bash
G="$(gatlas ensure)"
graphify explain  "UserService" --graph "$G"
graphify affected "UserService" --graph "$G"   # what breaks if this changes
open "$(dirname "$G")/graph.html"
```

By project name instead, against the primary checkout — no freshness check, so prefer
`gatlas` when you are working in the repo:

```bash
bin/query.sh my-repo "how does authentication reach the database?"
```

## Worktrees

Graphify graphs a *directory*, not a branch — so one graph per worktree. Switch branches or
`git worktree add`, and `gatlas` resolves to the right slot on its own; there is nothing
to configure and no second `scope-add`. A graph built from a different commit than your HEAD
is rebuilt before it is used, so an agent can never answer from another branch's parse.

Closing a worktree leaves its graph behind, ~60 MB each — `gatlas gc --prune` reclaims it.

A refresh also registers the primary checkout's graph under the project name in graphify's own
registry (`graphify global list`), so `graphify global path` can cross project boundaries.

## On a new machine

```bash
git clone <this repo> && cd graphify-atlas
bin/install.sh                        # the graphify CLI
bin/install-cli.sh                    # gatlas on PATH
bin/scope-add.sh ~/Projects/my-repo   # scope.tsv is created on first run
```

`scope.tsv` is gitignored: this repo has a public remote, and every row names a local path
to an employer or client project. That is personal data, so it does not travel with the
repo — you re-declare scope per machine.

Paths in it are stored `~`-relative, so a copied file survives a different username. A
project whose folder is missing shows as `gone` in `gatlas list` and is skipped.

## Notes

- PyPI package is `graphifyy` (two y's); the binary is `graphify`. The docs warn about
  lookalike packages.
- Extras default to `mcp`. Change with `GRAPHIFY_EXTRAS="mcp,watch" bin/install.sh`.
- Graphs get large — `GRAPHIFY_MAX_GRAPH_BYTES` guards at 512 MiB by default. That is
  why `graphs/` is gitignored.
- Requires Python 3.10+. `uv` provisions its own interpreter; `pipx` uses yours.
