# graphify-atlas

Central [Graphify](https://docs.graphify.com) knowledge base for selected local projects. It holds
the scope manifest and every tracked project's graph. It holds no application code.

Read `README.md` for the human-facing version. This file is the contract for agents.

## Layout

| Path | What | Committed |
|---|---|---|
| `scope.tsv` | tracked projects: `name<TAB>path<TAB>mode` | **no** — see below |
| `scope.tsv.example` | header-only starter for a fresh clone | yes |
| `bin/` | the scripts — the only supported interface | yes |
| `templates/graphifyignore` | `.graphifyignore` starter | yes |
| `graphs/<project>/<slot>/` | one graph per worktree; `_primary` is the main checkout | **no** |
| `AI_TASKS/` | plans and notes | no (global `~/.gitignore`) |

**`scope.tsv` is gitignored on purpose.** This repo has a public remote, and every row names a
local path to an employer or client project. Scope is per-machine personal data; the repo is the
tool. Never `git add -f` it.

`scope.tsv` stores paths `~`-relative. Read it through `bin/lib.sh` helpers, not by hand-parsing.

## Use the scripts

```bash
bin/install.sh [--upgrade]                 # install the graphify CLI (uv, fallback pipx)
bin/scope-add.sh <path> [opts]             # track a project + build its graph
bin/scope-remove.sh <name> [--purge]
bin/scope-list.sh                          # every slot, with branch + freshness
bin/refresh.sh [name ...] [--all-worktrees]
bin/query.sh <name> "<question>"           # the PRIMARY checkout, by name
bin/graph.sh ensure|query|status|path [dir]  # the worktree you are standing in
bin/graph-gc.sh [--prune]                  # drop slots whose worktree is gone
bin/install-cli.sh                         # symlink `gatlas` onto PATH
```

`gatlas` is a symlink to `bin/graph.sh` and fronts every command, so edits here are live with
nothing to reinstall. All scripts resolve through symlinks to find `lib.sh`.

**Agents use `bin/graph.sh`, never a graph path directly.** graphify graphs a
*directory*, so with worktrees and branch switching, reading a `graph.json` yourself means
silently answering from another branch's parse. `bin/graph.sh ensure` resolves the worktree you
are in, rebuilds if the graph does not match its HEAD, and only then prints the path. Its stdout
is the path and nothing else; progress goes to stderr. Exit 2 means "not a tracked project" —
fall back to grep and say so, never guess.

Don't hand-roll `graphify extract` / `graphify global` calls — `bin/refresh.sh` owns extraction,
output location and registry sync. Fix the script if it's wrong.

## Rules

- **Graph output is never committed.** `graphs/*` is gitignored. If something wants to commit a
  `graph.json`, that's a bug, not a decision to revisit.
- **`--code-only` is the default and stays the default.** It parses locally with no API key and
  sends nothing off the machine — correct for Wazo and client code. `--semantic` is opt-in per
  project, chosen by the user, never inferred.
- **Never run `graphify install`, in any form.** The global form writes user-level instructions and
  PreToolUse hooks that fire in *every* project. The `--project` form is no better here: agent
  wiring belongs in a skill, not in each tracked repo's tree.
- **Only `--ignore-template` writes into a tracked project.** Everything else here is read-only
  toward the projects it maps — discovery is `git rev-parse`, nothing more. Keep it that way.
- **No MCP server.** `graphify-mcp` serves one graph per process, which can't express per-worktree
  graphs. Agents reach the graph through `bin/`.
- **Adding a project is the user's call.** Don't put something in scope because it seemed useful.

## Querying a tracked project

Graphs live here, not beside the code, so every read command needs an explicit graph path:

```bash
bin/query.sh my-repo "how does auth reach the database?"
graphify explain "UserService" --graph graphs/my-repo/graph.json
graphify path "A" "B"          --graph graphs/my-repo/graph.json
graphify global path                      # crosses tracked projects
```

Build the path with `graph_json <name>` from `bin/lib.sh` rather than spelling it out.

A missing graph means it was never built — run `bin/refresh.sh <name>`, don't work around it.

## Gotchas

- PyPI package is `graphifyy` (two y's); the binary is `graphify`. The docs warn about lookalikes.
- **Never use `graphify extract --out DIR`.** It redirects `graph.json` but still writes a
  stat-index cache into `<scanned project>/graphify-out/` — a write into a tracked project. Drive
  every graphify command with an absolute `GRAPHIFY_OUT` instead; it redirects the graph, the
  report and all caches, and leaves the project untouched.
- `graphify extract` writes `graph.json` and stops. `graph.html` and `GRAPH_REPORT.md` come from
  `graphify cluster-only <project path>`, which `bin/refresh.sh` runs as a second step.
- `cluster-only` names communities with an **LLM by default**. `--no-label` is mandatory for
  `code-only` projects, or the run makes API calls that `--code-only` exists to prevent.
- `graphify` never fetches or pulls (except `graphify clone`). Syncing a ref is the caller's job.
- A graph carries a top-level `built_at_commit`, stamped from the analysed repo's HEAD — use it
  for staleness checks instead of tracking build times separately.
- Graphs get large: ~61 MB of output for a 16k-node repo. `GRAPHIFY_MAX_GRAPH_BYTES` guards at
  512 MiB.
- Requires Python 3.10+. `uv` brings its own interpreter, `pipx` uses yours.

## Shell conventions

`bash`, `set -euo pipefail`, `source bin/lib.sh` for `info`/`warn`/`die` and the scope helpers.
POSIX-ish tools only (`awk`, `sed`, `cut`) — this has to run on a fresh clone with no extras.
