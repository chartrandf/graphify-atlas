---
name: graphify-atlas
description: Answer structural questions about the current repo from its Graphify code graph instead of grepping blind. Use when asked how a system works, where something lives, what calls what, what depends on something, what breaks if X changes, or to trace a flow across files — "how does X reach Y", "what calls X", "what depends on X", "trace the flow", "the architecture of", "where is X implemented". Falls back to normal search, and says so, when the repo is not tracked.
---

# Graphify Atlas

`gatlas` answers structural questions from a parsed graph of the repo you are standing in.
Reach for it **before** fanning out with Grep/Glob on a "how does this work" question.

## When this beats searching

- how does X reach Y · what calls X · what depends on X
- what breaks if I change X
- where is X implemented, when the answer spans files
- tracing a flow through layers

**Not** for plain text search — a literal string, a TODO, a config value, a specific filename.
Grep is the right tool there and is faster.

## How

**1. Check the repo is tracked.**

```bash
gatlas status
```

Exit code **2** means it is not tracked. Say this once, then use ordinary search:

> No graphify graph for this repo — using search instead. It can be added to the atlas if you want one.

Never add it yourself. Putting a project in scope is the user's call.

**2. Ask.**

```bash
gatlas query "how does the unread count reach the UI?"
```

This resolves the worktree you are in, rebuilds the graph if it no longer matches HEAD
(~9s warm, ~16s cold), and only then answers. You do not need to refresh anything by hand.

**3. Drill into a specific node.**

```bash
G="$(gatlas ensure)"                          # prints the graph path, rebuilding if stale
graphify explain  "CallKitManager" --graph "$G"
graphify affected "SomeType"       --graph "$G"   # what breaks if this changes
graphify path "A" "B"              --graph "$G"
```

## Rules

- **Never read a `graph.json` directly, and never hardcode a path under `graphs/`.** There is one
  graph per *worktree*. With branch switching and `git worktree add`, a hardcoded path silently
  answers from a different branch's parse. `gatlas` is the only entry point that guarantees the
  graph matches the code in front of you.
- **The graph is a map, not the territory.** It is an AST-derived index and can be incomplete —
  dynamic dispatch, DI, reflection and string-keyed lookups are exactly what it misses. Use it to
  find *where to look*, then read those files and confirm before asserting anything.
- Graph output is `--code-only` by default: parsed locally, nothing sent anywhere.
- `gatlas` never writes into the repo you are working in.
- After closing a worktree, `gatlas gc --prune` reclaims its graph (~60 MB each).

## Other commands

```bash
gatlas status        # project, slot, branch, built-from sha, current or stale
gatlas list          # every tracked project and worktree slot
gatlas refresh <name> [--all-worktrees]
gatlas gc [--prune]
```

This skill ships from the atlas repo and is symlinked here, so it tracks whatever is committed
there. To find that repo: `dirname "$(dirname "$(readlink "$(command -v gatlas)")")"`.
