---
argument-hint: <c-source-path-or-module>
description: Stage 1 — comprehend a C module + its tests into reviewable specs
allowed-tools: Task, Read, Glob, Bash
model: sonnet
---

# /spec — Stage 1: comprehension

You are the orchestrator for Stage 1 of the C → Rust pipeline. The
target module is: **`$ARGUMENTS`** (a path or directory under
`c-source/`).

This command runs in the main thread, so you (and only you) can talk to
the developer. Subagents cannot. Do the steps below in order. Do **not**
read C source files yourself — that is the readers' job, and reading
both code and test files in this thread would defeat the isolation wall.

---

## Step 1 — Capture the developer's chain-of-thought

Ask the developer the three questions below, one message at a time, and
wait for an answer before continuing. Quote the answers verbatim later
when you brief `dev-helper`; do not paraphrase.

1. **Goal** — What is this module's purpose, in one or two sentences?
   What problem does it solve in the larger C codebase?
2. **Assumptions and foot-guns** — What do you already suspect about its
   scope, dependencies, threading model, allocation strategy, error
   handling style, or any historical foot-guns we should flag?
3. **Suspected idiomatic-Rust mappings** — Which Rust idioms do you
   guess will apply (e.g. `Result<T, E>` over error codes, traits over
   function-pointer tables, `Vec`/`Box` over manual allocation)? It is
   fine to say "not sure".

If the developer answers tersely, ask one short follow-up to draw out
the reasoning, but do not interrogate.

---

## Step 2 — Dispatch readers in parallel

Send a single message that contains **two `Task` tool calls in
parallel**:

- `subagent_type: c-code-reader` with a prompt that includes:
  - the target path `$ARGUMENTS`
  - the developer's COT answers (verbatim) as background
  - an instruction to produce `specs/code/<module>.spec.md`
  - a reminder: "You may not read C test files. The hook will block you
    if you try."
- `subagent_type: c-test-reader` with the same target path and COT
  answers, instructed to produce `specs/tests/<module>.spec.md`, with
  the mirror reminder.

Wait for both to return. If either fails because the path contains no
test files (or no non-test files), record that fact and continue — a
missing spec on one side is acceptable and gets noted in the log.

---

## Step 3 — Dispatch `dev-helper` to log the run

Send one `Task` call with `subagent_type: dev-helper`. The prompt must
include:

- Stage: `spec`
- Slug: a short kebab-case slug derived from `$ARGUMENTS`
- Command invocation: `/spec $ARGUMENTS`
- Developer COT (verbatim, all three answers)
- Subagents dispatched: `c-code-reader`, `c-test-reader`
- For each subagent: the file path it produced (or "skipped — no
  matching files")
- Any open questions raised by either reader

`dev-helper` will write a single file under `prompt-log/` and then run
the `checkpoint-review` skill to ask the developer "happy?".

---

## Step 4 — Hand off to the human

After `dev-helper` returns, surface to the developer:

- The two spec file paths (or one, if the other was skipped)
- The "happy?" prompt from `checkpoint-review`
- A reminder that **`/plan` should not be run until both specs have
  been reviewed by a human** (CLAUDE.md §4, Stage 1 → 2 gate).

Do **not** advance to `/plan` yourself.
