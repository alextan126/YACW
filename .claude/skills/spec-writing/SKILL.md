---
name: spec-writing
description: The heading template and writing rules for specs/code/** and specs/tests/**. Use whenever writing a spec file. Defines the seven required sections, what each must contain, and the absolute prohibition on translated code in specs.
---

This skill defines the shape of a spec file — both
`specs/code/<module>.spec.md` (written by `c-code-reader`) and
`specs/tests/<module>.spec.md` (written by `c-test-reader`). The
template is the same; the section *contents* differ.

A spec is for two readers: a human reviewer at the Stage 1 → 2 gate,
and a planner subagent who turns it into a translation plan. Write
for both.

## Heading template

Every spec uses these `##` headings, in this order:

```markdown
# <module name as it appears in the file path, verbatim>

> One- or two-sentence elevator pitch: what this module is, in plain
> English. Quote of the spec writer's own framing, not C comments.

## Purpose

What problem the module solves in the larger codebase. Two paragraphs
maximum. Avoid "this module …" boilerplate.

## Public surface

Bulleted list of every exported symbol — functions, types, macros,
globals — with the original C identifier verbatim and a one-line
description of intent. Do **not** show the C signature in full;
mention only the role of each parameter and the return.

For test specs: this section is "Test inventory" instead — one bullet
per test function, with the exact C name, the asserted behavior, and
the symbol(s) under test.

## Data model

Structs, unions, enums, key invariants. Use a small Markdown table or
a compact prose paragraph. Do not paste the C type declaration
verbatim; describe it.

For test specs: omit if there are no test-local types. Otherwise list
fixtures, fakes, mock types.

## Control flow

The main code paths in prose. Aim for one paragraph per top-level
public function. Mention loop direction, error-exit patterns
(`goto cleanup:` becomes `?` + RAII in Rust), and any state machine.

For test specs: describe the test framework's setup/teardown lifecycle
and any cross-test ordering assumptions.

## Memory & ownership notes

Who allocates, who frees, lifetime assumptions, threading
expectations. Use the pattern names from the `c-comprehension` skill
("owning raw pointer", "borrow-only", "out-parameter via `T**`",
etc.).

For test specs: any allocator hooks, leak-detection assumptions, or
fixtures that own resources.

## External dependencies

System headers, third-party libraries, other modules in `c-source/`
(by spec path), platform assumptions. One bullet each.

## Open questions

Anything unclear from the code alone that the planner or human
reviewer must resolve. Be specific: "Is `tbl_resize` expected to
preserve iteration order?" — not "tbl_resize is unclear".

If you have no open questions, write `- (none)`. Do not omit the
section.

## What not to write

- **No Rust.** Not even sketches. Not in code blocks, not in prose,
  not as type signatures. The planner does that.
- **No translated names.** `parse_input` stays `parse_input`, not
  `parseInput` or `ParseInput`.
- **No critique.** "This is poorly designed" is noise. State facts.
- **No simulation.** Do not run the code in your head and write down
  what it produces for example inputs. Describe what it *does*, not
  what it *would output*.

## Style

- Bullets and short paragraphs. No long prose dumps.
- C snippets only when essential, fenced as ```c. A snippet is
  essential if naming the pattern in prose would be longer than
  showing it.
- Mark every cross-reference to another spec as a Markdown link, e.g.
  `[hash_table](../code/hash_table.spec.md)`.
- Plain English. Avoid jargon the planner would not also use.

## Future tooling

Concrete helpers will live alongside this `SKILL.md`:

- A `template.md` to copy into a new spec.
- A linter that checks the seven required headings are present and
  in order.
- A cross-reference checker that verifies every symbol cited in
  `specs/tests/**` also appears in `specs/code/**`.

Until those exist, follow the template by hand.
