---
description: Show pending Rust diffs and the most recent prompt-log entries
allowed-tools: Read, Glob, Bash
model: sonnet
---

# /review — show what's pending and what's been logged

This is a read-only summary command. It does not dispatch subagents and
does not write any files.

## Step 1 — Pending Rust diffs

Run, via Bash:

- `git -C "$CLAUDE_PROJECT_DIR" status --short rust-output/`
- `git -C "$CLAUDE_PROJECT_DIR" diff --stat -- rust-output/`
- `git -C "$CLAUDE_PROJECT_DIR" diff -- rust-output/` (truncate to a
  reasonable length if very large; mention the full diff is available)

If the project is not a git repo, fall back to listing files in
`rust-output/` with `find rust-output -type f`.

## Step 2 — Recent prompt logs

List the five most recent files under `prompt-log/`, sorted by mtime
(newest first), with their first heading line shown next to each path.

- Bash: `ls -1t prompt-log/*.md 2>/dev/null | head -n 5` and read each.

## Step 3 — Spec / plan freshness check

Report whether the most recent prompt-log entry is older than
`specs/` or `plans/` (suggesting an unlogged change). This is a
heuristic for the reviewer, not a hard error.

## Step 4 — Pipeline state hint

Summarise where the developer is in the pipeline:

- **Stage 1 active** if `specs/` is empty or stale relative to
  `c-source/`.
- **Stage 2 active** if specs exist but `plans/` is empty or stale.
- **Stage 3 active** if plans exist and `rust-output/src/` has any
  uncommitted changes.

Print this as one or two sentences at the top of the response.
