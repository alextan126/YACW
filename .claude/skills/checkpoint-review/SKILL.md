---
name: checkpoint-review
description: How to present the end-of-run "happy?" checkpoint to the developer. Use after writing a prompt-log entry, at the end of any /spec, /plan, or /translate run. Defines a strict five-bullet summary format and the exact yes/no/revise question.
---

The checkpoint review is the developer's chance to bail out before
the pipeline advances. It runs at the end of every command, after the
prompt-log entry has been written. Its job is to surface what's worth
knowing, in a form the developer can scan in 15 seconds.

## Format

Output exactly the following block, after your `Wrote: prompt-log/...`
line:

```markdown
### Checkpoint summary

- **Produced**: <one-line, what concrete artefacts now exist>
- **Assumed**: <one-line, the most load-bearing assumption that was
  baked in this run; or "no notable assumptions">
- **Skipped / deferred**: <one-line, anything intentionally not done;
  or "nothing">
- **Look here first**: <one path the developer should open before
  approving>
- **Risk**: <one-line, the single thing most likely to bite if you
  proceed without revising; or "no notable risk">

**happy? (yes / no / revise)**
```

## Rules

- **Exactly five bullets.** Not four, not six. If you do not have
  content for a bullet, write the bullet anyway with the literal
  fall-back text shown above ("nothing", "no notable …").
- **One line per bullet.** A bullet that wraps to a second line is
  too long; trim it.
- **No markdown beyond the bullet itself.** No nested lists, no code
  blocks, no tables. Reviewers read this on their phone sometimes.
- **The question is the last line, verbatim.** Not "happy with this?"
  not "shall we proceed?". The literal string
  `**happy? (yes / no / revise)**`. The slash command's orchestrator
  matches on this string to know it has reached the gate.

## Mapping the answer

(For the orchestrating slash command, not the skill itself, but
recorded here so it stays in one place.)

- **yes** — proceed. The next stage may run; the human accepts the
  artefacts as written.
- **no** — stop. The run is recorded as `rejected` in its own
  follow-up log entry; the developer decides what to do.
- **revise** — re-dispatch the same stage's subagents with the
  developer's feedback added to the prompt. Loop until `yes` or
  `no`.

## What this is not

- It is not a code review. Reading the actual artefact is the
  developer's job.
- It is not a place to argue with the developer. Surface, don't
  defend.
- It is not optional. Every command ends with this block.
