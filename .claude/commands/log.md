---
argument-hint: <short-slug>
description: Record a hand-edit to specs/, plans/, or rust-output/ in prompt-log/
allowed-tools: Task, Read, Bash
model: sonnet
---

# /log — record a manual hand-edit

You are the orchestrator for a manual-edit log entry. The developer
just hand-edited something under `specs/`, `plans/`, or `rust-output/`
outside of any pipeline slash command, and per CLAUDE.md §5 they must
record it now. This command does **not** modify any artifact — it only
captures *what* changed and *why* into a `prompt-log/` entry.

The slug for this entry is `$ARGUMENTS`. If `$ARGUMENTS` is empty,
derive a kebab-case slug from the first edited path the developer
reports in step 1.

---

## Step 1 — Capture what was edited

Ask the developer the three questions below, one at a time, and quote
the answers verbatim when briefing `dev-helper`:

1. **Which paths did you edit?** One per line. Both new paths and
   modified paths. If you deleted something, prefix with `deleted:`.
2. **What did you change, in plain English?** The behavior or content
   of each edit, not a diff. Group by file if it helps.
3. **Why — and is anything upstream now stale?** What prompted the
   edit, and which spec, plan, or `plans/api/<unit>.md` (if any) is
   now out of sync with what you just wrote.

If the developer answers tersely, ask one short follow-up to draw out
the reasoning, but do not interrogate.

---

## Step 2 — Dispatch `dev-helper` to write the log

Send one `Task` call with `subagent_type: dev-helper`. The prompt must
include:

- Stage: `manual`
- Slug: `$ARGUMENTS` (or derived from the first edited path if empty)
- Command invocation: `/log $ARGUMENTS`
- Developer COT (verbatim, all three answers)
- Paths edited: the list from question 1
- Upstream impact: the answer to question 3 (which specs / plans /
  api docs are now stale, or "none stated")

`dev-helper` will write a single file at
`prompt-log/YYYY-MM-DD-HHMM-manual-<slug>.md` per the
`prompt-logging` skill (which has a `manual`-stage variant), then run
the `checkpoint-review` skill to ask the developer "happy?".

---

## Step 3 — Hand off to the human

Surface to the developer:

- The log file path that `dev-helper` wrote.
- The `checkpoint-review` summary and the "happy?" prompt from
  `dev-helper`.
- A reminder that **if any spec or plan was reported stale, it should
  be re-run** through `/spec` or `/plan` before the next
  `/translate`. `/log` does not auto-trigger that re-run.

Do **not** dispatch `c-code-reader`, `c-test-reader`, `code-planner`,
`test-planner`, `translator`, or `test-translator` from `/log`. This
command logs only.
