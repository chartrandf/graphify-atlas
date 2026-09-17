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
bin/scope-add.sh ~/Projects/my-repo # track a project and build its graph
bin/scope-list.sh                   # see what is tracked
```

That is the whole setup. `bin/install.sh` is idempotent; re-run it (or `--upgrade`) any time.

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
bin/refresh.sh [name ...]              # rebuild; no args = everything
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

Graphs live here rather than beside the code, so read commands need `--graph`:

Working inside a tracked project — this resolves the worktree you are in and rebuilds
it first if the graph no longer matches your HEAD:

```bash
bin/graph.sh query "how does authentication reach the database?"
bin/graph.sh status          # which slot, which branch, current or stale
```

By project name, against the primary checkout:

```bash
bin/query.sh my-repo "how does authentication reach the database?"
graphify explain "UserService" --graph graphs/my-repo/_primary/graph.json
open graphs/my-repo/_primary/graph.html
```

## Worktrees

Graphify graphs a *directory*, not a branch — so one graph per worktree. Switch branches or
`git worktree add`, and `bin/graph.sh` resolves to the right slot on its own; there is nothing
to configure and no second `scope-add`. A graph built from a different commit than your HEAD
is rebuilt before it is used, so an agent can never answer from another branch's parse.

Closing a worktree leaves its graph behind — `bin/graph-gc.sh --prune` reclaims it.

`bin/refresh.sh` also registers each graph under its name in graphify's own registry
(`graphify global list`), so `graphify global path` can cross project boundaries.

## On a new machine

```bash
git clone <this repo> && cd graphify-atlas
bin/install.sh
bin/scope-add.sh ~/Projects/my-repo   # scope.tsv is created on first run
```

`scope.tsv` is gitignored: this repo has a public remote, and every row names a local path
to an employer or client project. That is personal data, so it does not travel with the
repo — you re-declare scope per machine.

Paths in it are stored `~`-relative, so a copied file survives a different username. A
project whose folder is missing shows as `gone` in `bin/scope-list.sh` and is skipped.

## Notes

- PyPI package is `graphifyy` (two y's); the binary is `graphify`. The docs warn about
  lookalike packages.
- Extras default to `mcp`. Change with `GRAPHIFY_EXTRAS="mcp,watch" bin/install.sh`.
- Graphs get large — `GRAPHIFY_MAX_GRAPH_BYTES` guards at 512 MiB by default. That is
  why `graphs/` is gitignored.
- Requires Python 3.10+. `uv` provisions its own interpreter; `pipx` uses yours.
