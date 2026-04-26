---
description: Stage 2 — turn the reviewed specs into ordered translation plans
allowed-tools: Task, Read, Glob, Bash
model: sonnet
---

# /plan — Stage 2: planning

You are the orchestrator for Stage 2. The specs under `specs/code/` and
`specs/tests/` should already exist and have been reviewed by a human
(CLAUDE.md §4, Stage 1 → 2 gate).

This command runs in the main thread. Do **not** read individual spec
files yourself; the planners will read their respective trees.

---

## Step 0 — Confirm the gate

Briefly list the spec files that exist:

- `specs/code/**/*.spec.md`
- `specs/tests/**/*.spec.md`

Then ask the developer: "Have both specs been reviewed and approved?"
If the answer is no, stop and instruct them to review first. Do not
dispatch planners.

---

## Step 1 — Capture the developer's chain-of-thought

Ask the developer two questions, one at a time, and quote the answers
verbatim when briefing `dev-helper`:

1. **Translation order priorities** — Which units should be translated
   first? Are there ABI seams, leaf utilities, or risky modules that
   should be sequenced deliberately? Any unit you want left for last?
2. **Anti-patterns to avoid** — Are there C idioms in this codebase
   that you specifically want the translator to *not* mirror in Rust
   (e.g. "do not port the linked-list directly, prefer `Vec`")? Any
   `unsafe` boundaries you want explicitly forbidden?

---

## Step 2 — Dispatch planners in parallel

Send a single message with **two parallel `Task` calls**:

- `subagent_type: code-planner` — instruct it to read `specs/code/**`
  only, and produce `plans/code-plan.md`. Pass the developer's COT
  answers as background. Remind it that the hook will block reads
  outside `specs/code/` and `plans/code-plan.md`.
- `subagent_type: test-planner` — mirror, producing `plans/test-plan.md`
  from `specs/tests/**`.

The plans must include:

- A dependency-ordered list of translation units.
- Per-unit Rust idiom mapping (referencing the `translation-patterns`
  skill where applicable).
- Explicit `unsafe`-avoidance notes per unit.
- Open questions for the human reviewer.

---

## Step 3 — Dispatch `dev-helper` to log the run

`subagent_type: dev-helper`, with:

- Stage: `plan`
- Slug: short kebab-case slug describing the planning round (e.g.
  `initial`, `revision-1`)
- Command invocation: `/plan`
- Developer COT (verbatim)
- Subagents dispatched: `code-planner`, `test-planner`
- Files produced: `plans/code-plan.md`, `plans/test-plan.md`
- Open questions surfaced by either planner

---

## Step 4 — Hand off to the human

Surface the two plan paths plus the `checkpoint-review` "happy?" prompt.
Remind the developer that **`/translate` may not be run until the plan
has been approved** (CLAUDE.md §4, Stage 2 → 3 gate). Do not advance.
