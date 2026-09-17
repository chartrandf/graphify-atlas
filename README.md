# graphify-atlas

> **Scope it, graph it, keep it out of the repo.**

Central [Graphify](https://docs.graphify.com) knowledge base for selected local projects.

One folder holds the scope manifest and every project's graph. Nothing is written into
the tracked projects unless you ask for it, and no analysis output is ever committed.

```
scope.tsv          which projects are tracked   (committed)
graphs/<name>/     graph.json, graph.html, GRAPH_REPORT.md   (gitignored)
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
  --claude           wire it into Claude Code for that project
  --ignore-template  drop templates/graphifyignore into the project
  --no-extract       record it now, build later

bin/scope-remove.sh <name> [--purge]   # --purge also deletes graphs/<name>
bin/refresh.sh [name ...]              # rebuild; no args = everything
```

`--code-only` is the default on purpose — it is the safe mode for client and employer
code. Opt into `--semantic` per project, knowingly.

`--claude` is the only flag that writes into the tracked project: it runs
`graphify install --project --platform claude` there (project-scoped instructions and
PreToolUse hooks) and adds a local-scope MCP server pointing at the central graph. Undo
it with `graphify uninstall --project --platform claude` from that project.

Never run the bare `graphify install` — the global form installs instructions and hooks
that fire in *every* project, which is exactly what this repo exists to avoid.

## Querying

Graphs live here rather than beside the code, so read commands need `--graph`:

```bash
bin/query.sh my-repo "how does authentication reach the database?"

graphify explain "UserService" --graph graphs/my-repo/graph.json
graphify path "A" "B"          --graph graphs/my-repo/graph.json
open graphs/my-repo/graph.html
```

`bin/refresh.sh` also registers each graph under its name in graphify's own registry
(`graphify global list`), so `graphify global path` can cross project boundaries.

## On a new machine

```bash
git clone <this repo> && cd graphify-atlas
bin/install.sh
bin/refresh.sh        # rebuilds every graph in scope.tsv from local checkouts
```

Paths in `scope.tsv` are stored `~`-relative, so they survive a different username. A
project whose folder is missing shows as `gone` in `bin/scope-list.sh` and is skipped.

## Notes

- PyPI package is `graphifyy` (two y's); the binary is `graphify`. The docs warn about
  lookalike packages.
- Extras default to `mcp`. Change with `GRAPHIFY_EXTRAS="mcp,watch" bin/install.sh`.
- Graphs get large — `GRAPHIFY_MAX_GRAPH_BYTES` guards at 512 MiB by default. That is
  why `graphs/` is gitignored.
- Requires Python 3.10+. `uv` provisions its own interpreter; `pipx` uses yours.
