---
name: prompt-logging
description: How to write a single prompt-log entry for a /spec, /plan, /translate, or /log run. Use whenever writing a file under prompt-log/, or when asked to summarize a pipeline run for the record. Defines filename format, section template, and what each section must contain. Includes a manual-stage variant for /log entries that record hand-edits.
---

A prompt-log entry is the single source of truth for what happened in
one slash-command run of the C → Rust pipeline. It is read by humans
later, sometimes much later, to understand *why* a translation
decision was made.

## Filename

```
prompt-log/YYYY-MM-DD-HHMM-<stage>-<slug>.md
```

- `YYYY-MM-DD-HHMM` — local time the run started, zero-padded.
- `<stage>` — one of `spec`, `plan`, `translate`, `manual`.
- `<slug>` — short kebab-case. For `/spec` and `/translate`, derive
  from the unit / module path (e.g. `parser-lexer`, `hash-table`).
  For `/plan`, use `initial`, or `revision-1`, `revision-2`, etc.
  For `/log` (stage `manual`), use the developer-provided slug, or
  derive from the first edited path.

If a file with the same name already exists (rare, but possible
within a minute), append `-2`, `-3`, etc.

## Section template

Each entry is a single Markdown file with these sections, in this
order, using these exact `##` headings:

```markdown
# <Stage> run: <slug>

- **When**: <YYYY-MM-DD HH:MM TZ>
- **Command**: `<exact /command line>`
- **Stage**: <spec | plan | translate | manual>
- **Outcome**: <succeeded | partial | rejected | aborted>

## Developer chain-of-thought

> Verbatim answers to the command's COT questions, quoted as a
> blockquote. One subsection per question, with the question text as
> the subsection header.

### <Question 1 text>

> <verbatim answer>

### <Question 2 text>

> <verbatim answer>

(...as many as the command asked)

## Subagents dispatched

- **<name>**
  - Inputs: <files / args>
  - Outputs: <files written>
  - Note: <one-line note>

## Files produced

- `<path>` — <one-line description of what's in it>
- ...

## `unsafe` blocks introduced

(Only present for `/translate` runs.)

- Count: <N>
- Locations: `<file>:<line>` — <one-line justification copied from
  the comment immediately above the block>

## Open questions

- <question 1, with what would unblock it>
- <question 2>

## Next checkpoint

- <one sentence: what the developer should do next, e.g. "Review
  specs/code/parser/lexer.spec.md and specs/tests/parser_test.spec.md
  before running /plan.">
```

## Manual-stage variant (`/log`)

When the stage is `manual`, the entry was written by `/log` to record
a hand-edit the developer made outside any pipeline command. Use the
same skeleton above, with two substitutions:

- Replace the `## Subagents dispatched` section with `## Paths edited`,
  a bullet list of the file paths the developer reported in question 1
  of `/log` (preserve the `deleted:` prefix for deletions).
- Replace the `## Files produced` section with `## Upstream impact`,
  one bullet per upstream artefact the developer flagged as stale, or
  a single bullet `- None reported.` if they said nothing was stale.
  Each bullet should name the stale path and what re-run would
  refresh it (e.g. `specs/code/parser.spec.md — re-run /spec
  c-source/parser.c`).

The `## Developer chain-of-thought`, `## Open questions`, and
`## Next checkpoint` sections stay exactly as in the standard
template. Manual-stage entries never have `## unsafe blocks
introduced` — that section only applies to `/translate`.

## Rules for the writer

- **Quote, don't paraphrase.** Developer COT is preserved verbatim.
  This is non-negotiable — paraphrasing in the log will destroy the
  log's later usefulness.
- **One file per run.** Never append to a previous run's file.
- **Missing inputs become `(not provided)`** plus an entry under
  `Open questions`. Do not invent values.
- **No translated code in the log.** Snippets are fine; full
  translations belong in `rust-output/`.
- **Keep it short.** A typical entry is one screen of Markdown. The
  log is an index, not a transcript.
