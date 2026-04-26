## Future tooling

#c-comprehension

Concrete scripts will live next to this `SKILL.md` and provide:

- A function-level call graph for the target path.
- A typedef / struct dependency graph.
- A macro expansion preview (read-only).
- A `cscope` / `ctags` query helper.

#spec-writing

Concrete helpers will live alongside this `SKILL.md`:

- A `template.md` to copy into a new spec.
- A linter that checks the seven required headings are present and
  in order.
- A cross-reference checker that verifies every symbol cited in
  `specs/tests/**` also appears in `specs/code/**`.

#translation-patterns

Concrete helpers will live next to this `SKILL.md`:

- A pattern-recognition assistant that, given a spec excerpt, suggests
  the matching row in the tables above.
- A linter for `rust-output/` that flags `unsafe` blocks without the
  required justification comment.
- A small library of pre-canned safe wrappers for common FFI shapes.
