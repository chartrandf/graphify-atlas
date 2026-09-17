# graphify-atlas

Central [Graphify](https://docs.graphify.com) knowledge base for selected local projects. It holds
the scope manifest and every tracked project's graph. It holds no application code.

Read `README.md` for the human-facing version. This file is the contract for agents.

## Layout

| Path | What | Committed |
|---|---|---|
| `scope.tsv` | tracked projects: `name<TAB>path<TAB>mode` | yes |
| `bin/` | the scripts — the only supported interface | yes |
| `templates/graphifyignore` | `.graphifyignore` starter | yes |
| `graphs/<name>/` | `graph.json`, `graph.html`, `GRAPH_REPORT.md` | **no** |
| `AI_TASKS/` | plans and notes | no (global `~/.gitignore`) |

`scope.tsv` stores paths `~`-relative. Read it through `bin/lib.sh` helpers, not by hand-parsing.

## Use the scripts

```bash
bin/install.sh [--upgrade]                 # install the graphify CLI (uv, fallback pipx)
bin/scope-add.sh <path> [opts]             # track a project + build its graph
bin/scope-remove.sh <name> [--purge]
bin/scope-list.sh
bin/refresh.sh [name ...]                  # rebuild; no args = all
bin/query.sh <name> "<question>"
```

Don't hand-roll `graphify extract` / `graphify global` calls — `bin/refresh.sh` owns extraction,
output location and registry sync. Fix the script if it's wrong.

## Rules

- **Graph output is never committed.** `graphs/*` is gitignored. If something wants to commit a
  `graph.json`, that's a bug, not a decision to revisit.
- **`--code-only` is the default and stays the default.** It parses locally with no API key and
  sends nothing off the machine — correct for Wazo and client code. `--semantic` is opt-in per
  project, chosen by the user, never inferred.
- **Never run the bare `graphify install`.** The global form writes user-level instructions and
  PreToolUse hooks that fire in *every* project. Only ever `graphify install --project`, from the
  tracked project's root — that's what `bin/scope-add.sh --claude` does.
- **Only `--claude` and `--ignore-template` write into a tracked project.** Everything else here
  is read-only toward the projects it maps. Keep it that way.
- **Adding a project is the user's call.** Don't put something in scope because it seemed useful.

## Querying a tracked project

Graphs live here, not beside the code, so every read command needs an explicit graph path:

```bash
bin/query.sh my-repo "how does auth reach the database?"
graphify explain "UserService" --graph graphs/my-repo/graph.json
graphify path "A" "B"          --graph graphs/my-repo/graph.json
graphify global path                      # crosses tracked projects
```

A missing `graphs/<name>/graph.json` means it was never built — run `bin/refresh.sh <name>`, don't
work around it.

## Gotchas

- PyPI package is `graphifyy` (two y's); the binary is `graphify`. The docs warn about lookalikes.
- `graphify-mcp` serves **one graph per process**. Wiring N projects means N MCP entries with
  distinct names, not one server.
- `claude mcp add` defaults to `-s local` (this project, private). Never `-s user` — that's the
  global leak this repo avoids. Never `-s project` — graph paths are absolute and machine-local.
- Graphs get large; `GRAPHIFY_MAX_GRAPH_BYTES` guards at 512 MiB.
- Requires Python 3.10+. `uv` brings its own interpreter, `pipx` uses yours.

## Shell conventions

`bash`, `set -euo pipefail`, `source bin/lib.sh` for `info`/`warn`/`die` and the scope helpers.
POSIX-ish tools only (`awk`, `sed`, `cut`) — this has to run on a fresh clone with no extras.
