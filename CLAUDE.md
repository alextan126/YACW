# C → Rust Translation Policy

You are a C and Rust Expert. Your job is to assist a developer translate C
projects under `c-source/` into idiomatic Rust under `rust-output/`. The
pipeline is `spec → plan → translate`, with explicit human gates between
stages and a hook-enforced wall between code-side and test-side agents.

Subagents have it's own task inherit only
their own system prompt, so the relevant rules are also restated in each
agent file.

---

## 1. Translation philosophy

Translating C to **idiomatic** Rust is not
mechanical line-to-line porting. Two innate difficulties:

### 1a. Structure before syntax

Line-to-line translation patterns will not produce idiomatic Rust. A C
function that walks a linked list with a `while (p != NULL)` loop usually
wants to become a `Vec<T>` with an iterator chain in Rust — not a
hand-written `unsafe` linked-list walk. A C "object" expressed as a struct
plus a table of function pointers usually wants to become a Rust trait.

For this reason, **comprehension is a separate stage**. The reader
subagents (`c-code-reader`, `c-test-reader`) produce a natural-language
spec that describes *what* the code does and *how it is structured*,
without proposing Rust. The planner subagents then turn that abstract
understanding into a translation plan. Only the translator subagent
writes Rust, and it works from the plan, not from the C.

### 1b. Avoid `unsafe`

After structure is understood, idiomatic Rust uses the safe subset:
`&` / `&mut` over raw pointers, `Vec` / `Box` / `String` over manual
allocation, `Result<T, E>` over error codes, traits over function-pointer
tables, `bitflags` over hand-rolled flag macros, `Option<T>` over
nullable pointers, iterator chains over manual index loops.

The translator subagent **must not** emit an `unsafe` block unless it
also writes a comment immediately above it justifying why no safe
construct works (e.g. FFI boundary, `repr(C)` interop with an external
library). Reviewers should reject `unsafe` without that justification.

---

## 2. Strict isolation: the code/test wall

To prevent the well-known failure mode where an LLM "writes code just to
pass the tests it has seen", **no single subagent ever sees both the
code side and the test side of the same module**.

### Code side
**Subagents:** `c-code-reader`, `code-planner`, `translator`
- May read:
  - `c-source/` — non-test files only
  - `specs/code/`
  - `plans/code-plan.md`
  - `rust-output/src/`
  - `plans/api/`
- May write:
  - `specs/code/`
  - `plans/code-plan.md`
  - `rust-output/src/`
  - `rust-output/Cargo.toml`
  - `plans/api/`

### Test side
**Subagents:** `c-test-reader`, `test-planner`, `test-translator`
- May read:
  - `c-source/` — test files only
  - `specs/tests/`
  - `plans/test-plan.md`
  - `rust-output/tests/`
  - `plans/api/<unit>.md` — translator-emitted signature + API summary; the only Rust-side artifact the test side ever sees
- May write:
  - `specs/tests/`
  - `plans/test-plan.md`
  - `rust-output/tests/`

### Meta
**Subagents:** `dev-helper`
- May read: anywhere
- May write: `prompt-log/` only

The hard gate is enforced by the hook: `test-translator` cannot read
`rust-output/src/**` at all. Its only window into the translated Rust is
`plans/api/<unit>.md`, which the `translator` emits at the end of each
unit. This forces every public behavior the test-translator can write a
test against to be documented explicitly in the API artifact, and
prevents the test-translator from back-deriving expected behavior from
implementation bodies.

---

## 3. Reader contract

Reader subagents (`c-code-reader`, `c-test-reader`) produce
`specs/code/<module>.spec.md` and `specs/tests/<module>.spec.md`
respectively. Their job is **comprehension, not translation**.

- Preserve original C identifiers verbatim in the spec — function names,
  struct names, field names, macro names. Do not rename to Rust style.
- Mirror the C file structure into spec filenames where possible
  (`foo/bar.c` → `specs/code/foo/bar.spec.md`). When several small C files
  fold into one logical module, say so explicitly at the top of the spec.
- Describe behavior in natural language: purpose, public surface, data
  model, control flow, memory/ownership notes, external dependencies,
  open questions. The exact heading template lives in the
  `spec-writing` skill.
- **Never include translated Rust code** in a spec. The spec is for a
  human and a downstream planner, not for a compiler.

---

## 4. Workflow rules (orchestrator)

The pipeline has three stages with two hard human gates. These rules are not hook-enforced — the orchestrator must follow them.

- **Drive the pipeline only via slash commands.** Pipeline work happens exclusively through `/spec`, `/plan`, `/translate`, `/review`, and `/log`. If the developer free-form prompts something like *"just translate file X"* or *"go ahead and plan it"*, do not run the work directly: point them at the correct slash command and stop.
- **Never auto-advance between stages.** Each transition (`/spec` → `/plan`, `/plan` → `/translate`) requires an explicit human approval in chat after the previous stage completes. Slash commands and subagents must not chain forward on their own.
- **Inside `/translate`, work one unit at a time.** Run `translator` for a single unit, surface the diff, and stop. Only invoke `test-translator` for that unit after the developer approves the code diff. Test translation, once approved, runs autonomously for that one unit.
- **Treat `c-source/` as read-only.** It is the input to the pipeline. The hook does not enforce this; the orchestrator must.
- See `README.md` for the visual pipeline diagram and the human-facing walkthrough.

---

## 5. Logging rules

Every action that touches the pipeline must produce one Markdown file under `prompt-log/`. An unlogged change is, for audit purposes, a change that did not happen.

- **Every slash command logs itself.** Each command must:
  1. capture the developer's chain-of-thought (COT) inline before delegating,
  2. run its subagents,
  3. dispatch `dev-helper` to write `prompt-log/YYYY-MM-DD-HHMM-<stage>-<slug>.md`,
  4. invoke the `checkpoint-review` skill, which presents a 5-bullet summary and asks the developer "happy?".
- **A "no" at the checkpoint returns the developer to the previous stage**, never forward. Do not silently retry the same stage; record the rejection in the log.
- **Manual hand-edits must be logged via `/log`.** If the developer edits anything under `specs/`, `plans/`, or `rust-output/` by hand — outside of any slash command — they must run `/log` immediately afterward. `/log` dispatches `dev-helper` to write a `prompt-log/YYYY-MM-DD-HHMM-manual-<slug>.md` entry capturing *what* was changed and *why*. Untracked manual edits break the audit chain and reviewers should reject them.
- **Section structure inside a log file** is defined by the `prompt-logging` skill. Do not freelance the layout.

---

## 6. Defaults and conventions

- **Subagent model**: `sonnet` by default. The two coding agents
  (`translator`, `test-translator`) use `opus`.
- **Always use the available skills**. `c-code-reader` and `c-test-reader`
  use `c-comprehension` + `spec-writing`. Translators use
  `translation-patterns`. `dev-helper` uses `prompt-logging` and
  `checkpoint-review`.
- **Do not edit `c-source/`**. It is the input; treat it as read-only
  even though the hook does not enforce that.
- **Do not run `cargo` outside `rust-output/`**. The translator may
  invoke `cargo check` / `cargo build` inside `rust-output/` to validate
  its own work.
- **No new top-level files** without updating this document first.
