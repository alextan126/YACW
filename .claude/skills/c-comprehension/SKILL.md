---
name: c-comprehension
description: How to read C source effectively for the purpose of writing a natural-language spec. Use whenever reading non-test C under c-source/ to produce specs/code/**. Covers identifier preservation, control-flow abstraction, and pointer / ownership pattern recognition. Future tooling under this directory will provide concrete scripts (call graphs, AST summaries); for now this is a behavioural guide.
---

This skill guides the `c-code-reader` (and any human reviewer) on
*how* to read C with comprehension as the goal — not translation, not
critique. The output is always natural-language prose at the level of
a `specs/code/<module>.spec.md` file.

## Posture

You are reading C the way an experienced systems engineer reads an
unfamiliar codebase to brief a colleague: top-down, names-first, and
suspicious of any convenience the language offers (macros, casts,
pointer arithmetic).

## Reading order

1. **Headers before sources.** Read `.h` files first to learn the
   public surface. They define the contract; the `.c` files implement
   it.
2. **Top-of-file comments and copyright headers.** These often state
   provenance, threading model, and known limitations that don't
   appear in code.
3. **Type definitions before functions.** Structs, unions, enums, and
   typedefs frame the data model. Get the data right, the control
   flow follows.
4. **Public functions before static helpers.** Public is the
   contract; static is the implementation. Spec the contract; mention
   helpers only when they encode an invariant.
5. **Macros last.** Macros that look like functions usually become
   Rust functions; macros that build types (`X(...)` table macros)
   often become traits or enums in Rust. Note them, do not expand
   them in the spec.

## Identifier preservation

- **Preserve every C identifier verbatim** in the spec — function
  names, struct names, field names, macro names, file names. The
  planner needs to cross-reference these against the test spec, and
  later the translator uses them to name the Rust equivalents.
- Do not rename to Rust style. Do not "improve" abbreviations. The
  one-word `tbl` stays `tbl` in the spec.

## Control-flow abstraction

- Replace bodies with prose. A 60-line C function with three nested
  loops becomes "iterates over each entry in `tbl->buckets`; for each
  non-empty bucket, walks the linked list and accumulates X into the
  caller-provided `out` buffer." That is the level of abstraction the
  planner wants.
- Keep loop *boundaries* and *direction* (forward, reverse, two-cursor)
  because they constrain the Rust idiom (iterator chain, `.rev()`,
  `windows()`, `zip()`).
- Mention `goto cleanup:` style flow explicitly — that pattern usually
  becomes `?` + RAII in Rust, but the planner needs to see it.

## Pointer & ownership pattern recognition

When you see a pointer, name its role. The planner uses these names.

- `T*` returned, caller frees — name in spec: **"owning raw pointer (caller frees)"**
- `T*` returned, callee owns — name in spec: **"borrowed pointer to internal storage"**
- `const T*` parameter — name in spec: **"borrow-only"**
- `T*` parameter, mutated — name in spec: **"in-out parameter"**
- `T**` parameter, set to a new alloc — name in spec: **"out-parameter via `T**`, owning"**
- `void*` + `size_t` length — name in spec: **"byte slice"**
- Nullable pointer — name in spec: **"nullable; absence is meaningful"**
- Function-pointer field in a struct — name in spec: **"vtable slot — likely a trait method"**

If a pointer's role is not clear from the code, say "unclear" and
list it as an open question. Do not guess.

## Memory & resource pattern recognition

- Note any custom allocator (`xmalloc`, arena, slab). Rust will need
  a different shape — flag it.
- Note manual reference counting (struct field `refcount`). It often
  becomes `Arc<T>`.
- Note any pattern that looks like RAII-by-convention (`init` /
  `destroy` pairs). It maps directly to `Drop`.

## What not to do

- Do not write Rust. Not even hypothetically. The planner does that.
- Do not critique the C. "This is bad design" is noise; "this
  function silently truncates on overflow" is signal — write the
  signal version.
- Do not simulate the code. If you cannot tell what a function does
  from its name, signature, and body, say so.

