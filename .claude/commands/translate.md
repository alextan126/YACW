---
argument-hint: <translation-unit>
description: Stage 3 — translate one approved unit, with a human gate before tests
allowed-tools: Task, Read, Glob, Bash
model: Opus
---

# /translate — Stage 3: translation (one unit at a time)

You are the orchestrator for Stage 3. The translation unit is:
**`$ARGUMENTS`** — this should be a unit name that appears in
`plans/code-plan.md` (and ideally `plans/test-plan.md`).

Code translation is **piece-by-piece with a human approval gate per
unit** (CLAUDE.md §4). Test translation runs autonomously after that
gate.

---

## Step 0 — Confirm the gate

Briefly confirm with the developer:

1. `plans/code-plan.md` and `plans/test-plan.md` both exist and have
   been approved.
2. The unit `$ARGUMENTS` is the next one in plan order (or, if
   re-translating, that this is intentional).

If either is unclear, stop and ask.

---

## Step 1 — Capture the developer's chain-of-thought

Ask one question, wait for the answer, and quote it verbatim later:

1. **Safety / idiom concerns for this unit** — Anything specific you
   want the translator to watch out for on this unit? Any `unsafe`
   boundary you expect to hit, or specifically want avoided? Any prior
   translated unit it must integrate with?

---

## Step 2 — Dispatch the `translator`

Send a `Task` call with `subagent_type: translator`. The prompt must
include:

- The unit name `$ARGUMENTS`.
- The developer's COT answer.
- Instruction: read only `plans/code-plan.md`, the relevant
  `specs/code/**` entries, any already-translated `rust-output/src/**`,
  and any prior `plans/api/**`. Do not read C source directly. The
  hook will block reads outside that zone.
- Instruction: any `unsafe` block must be preceded by a comment that
  justifies it; otherwise prefer the safe constructs in the
  `translation-patterns` skill.
- Instruction: produce **two** artefacts for this unit:
  1. Rust source under `rust-output/src/**` (and `rust-output/Cargo.toml`
     if new dependencies are needed).
  2. An API summary at `plans/api/<unit-slug>.md` documenting every
     public item this unit added or changed — signatures, error
     variants, panic conditions, ownership semantics, and a
     **Behavior contract** paragraph derived from the spec.
- Instruction: this API doc is the **only** view of the translated
  Rust the test-translator will have. The hook denies it any access
  to `rust-output/src/**`. If the API doc is missing or incomplete,
  there will be no Rust tests for those public items. Be complete.
- Instruction: fail loudly (end the turn with an open question) if
  you cannot produce the API doc — do not skip it.
- Instruction: end its turn with a short summary listing both the
  source files and the API doc path, plus any deviations from the
  plan.

Wait for it to return. If the translator's turn-end summary does not
include a `plans/api/<unit-slug>.md` line, treat that as a failure
and revise (Step 3, "revise" branch) — the test-translator cannot run
without it.

---

## Step 3 — Human approval gate

Surface to the developer:

- The list of files the translator created or modified under
  `rust-output/src/`.
- A `git diff` of `rust-output/src/` (you may run `git -C
  "$CLAUDE_PROJECT_DIR" diff -- rust-output/src/` via Bash).
- The contents of `plans/api/<unit-slug>.md` — read it and show it
  inline. The developer must verify the API doc matches the source,
  because it is the only thing the test-translator will see.
- A `git diff` of `plans/api/<unit-slug>.md` if a prior version
  existed.
- The translator's deviation notes.

Then ask: **"Approve this unit and proceed to test translation?
(yes / no / revise)"**

- If **yes**, continue to Step 4.
- If **revise**, take the developer's feedback and re-dispatch
  `translator` (Step 2) with the feedback added to the prompt. Loop
  until approved or aborted.
- If **no**, stop. Dispatch `dev-helper` (Step 5) with `outcome:
  rejected` and skip Step 4.

Do not invoke `test-translator` before this gate clears.

---

## Step 4 — Dispatch the `test-translator` (autonomous)

Send a `Task` call with `subagent_type: test-translator`. Prompt must
include:

- The unit name `$ARGUMENTS`.
- Instruction: read only `plans/test-plan.md`, `specs/tests/**`,
  `plans/api/<unit-slug>.md`, and existing `rust-output/tests/**`.
  The hook will deny any read of `rust-output/src/**` — that is
  deliberate; the translator's API doc is your only window into the
  Rust API.
- Instruction: write to `rust-output/tests/**`.
- Instruction: do not modify `rust-output/src/**`. The hook enforces
  this.
- Instruction: if `plans/api/<unit-slug>.md` is insufficient to
  write a test the plan requires, end your turn with that as an open
  question rather than guessing or trying to read the source.
- Instruction: end its turn with a list of test files written and
  any test that could not be translated (with a short reason).

This step does not have an explicit per-message human gate — it runs to
completion before returning to the developer.

---

## Step 5 — Dispatch `dev-helper` to log the run

`subagent_type: dev-helper`, with:

- Stage: `translate`
- Slug: kebab-case of `$ARGUMENTS`
- Command invocation: `/translate $ARGUMENTS`
- Developer COT (verbatim)
- Subagents dispatched: `translator`, plus `test-translator` if Step 4
  ran
- Outcome: `approved` / `revised-N-times` / `rejected`
- Files produced: list from translator and test-translator
- `unsafe` blocks introduced: count + locations (if any)
- Open questions

---

## Step 6 — Hand off to the human

Surface:

- The final diff summary for the unit.
- The `checkpoint-review` "happy?" prompt from `dev-helper`.
- A suggestion of the next unit from `plans/code-plan.md` (do not
  auto-run it).
