## How the pipeline works

This repo translates C to **idiomatic** Rust through three stages — `spec → plan → translate` — separated by two hard human gates and a hook-enforced wall between code-side and test-side agents.

### Stage 1 — Comprehension (`/spec <module>`)
Reader subagents (`c-code-reader`, `c-test-reader`) read the C source and produce natural-language specs under `specs/code/` and `specs/tests/`. Specs preserve original C identifiers and describe *what* the code does and *how it is structured* — they never propose Rust.

**Gate:** the developer reads both specs and approves before Stage 2.

### Stage 2 — Planning (`/plan`)
Planner subagents (`code-planner`, `test-planner`) turn the specs into ordered translation units with a dependency graph, written to `plans/code-plan.md` and `plans/test-plan.md`.

**Gate:** the developer approves both plans before Stage 3.

### Stage 3 — Translation (`/translate <unit>`)
The `translator` subagent emits Rust for one unit at a time. The developer reviews the diff per unit and approves before `test-translator` runs for that unit. Test translation, once approved, runs autonomously for that unit only.

## Logs are a primary deliverable

Every slash command writes a Markdown file under `prompt-log/` capturing the developer's chain-of-thought, the subagents that ran, and a checkpoint summary. The logs are on equal footing with the translated Rust — they are how a future reviewer reconstructs *why* a translation choice was made.

If the developer ever hand-edits a spec, plan, or generated Rust file outside of a slash command, they must run `/log` to record the manual change. The audit chain is only useful if it is complete.

## How to use this repo
- put c code under c-source. Seperate test and implementation. Suggested format: put all tests related code under ./c-source/test.
- All pipeline work goes through slash commands: `/spec`, `/plan`, `/translate`, `/review`, `/log`. Do not free-form prompt the agent to translate, plan, or spec — it will redirect you to the correct command. 
- Read both specs at the Stage 1 → 2 gate; read both plans at the Stage 2 → 3 gate. The agents will not advance without you.
- After any hand-edit, run `/log` immediately. Log first, ask questions later.
