---
description: Break a long recording/spec into discrete tasks, give each its own mini-PRD + plan, then build a dependency map (order, blockers) and load them into your task queue. No GitHub Issues required.
allowed-tools: Read, Write, Bash, Agent, Grep, Glob
---

# /decompose — from a long recording/spec to tasks with PRDs and dependencies

When a LARGE assignment arrives (a 10+ minute voice recording, a big spec) — don't
build everything from one giant PRD. Decompose it, so each piece gets its own
analysis, and so the order of work (what depends on what) is explicit.

## When to use
- Large / multi-task assignments (10+ min voice memo, a PRD, a master spec).
- NOT for a single trivial change.
- The backbone is **your own task queue** (whatever you already use — a tasks DB,
  a kanban board, a plain list). GitHub Issues are intentionally avoided here:
  keep it local, free, and without external rate limits / email noise.

## Procedure (loop 1 → map → queue)
1. **Input:** if it's a recording, transcribe it first (see `scripts/transcribe.sh`
   or your STT of choice); otherwise take the spec. READ IT IN FULL.
2. **Extract tasks:** pull out 5–10 DISCRETE tasks/features (no more — if there are
   more, group them). Each one = a single independently shippable thing.
3. **Per-task PRD + plan (in parallel):** for EACH task, spawn a sub-agent
   (planner / PRD writer, model sized to the difficulty) → its own mini-PRD: what,
   why, acceptance criteria, layers touched (DB / API / UI / tests), risks. Save to
   `.claude-context/decompose-<date>/<task>.md`.
4. **Dependency map (compare tasks against each other):** compare the tasks
   pairwise → what must exist FIRST, what BUILDS ON what, what BLOCKS what, what can
   run in PARALLEL. Output = an ordered graph in waves (wave 1 in parallel, wave 2
   depends on wave 1, …).
5. **Into the queue:** load the tasks into your task queue in the order from the
   graph, each linked to its PRD + its dependencies.
6. **Execution:** run the tasks through your normal flow — `/team` or a workflow,
   in parallel by wave, through the 3 gates of the Definition of Done
   (`rules/definition-of-done.md`): reverse-check against the assignment, Tester
   click-through (the user sees it), screenshot proof to the human.

## Output to the user
Short: "From the recording I derived N tasks, here's the dependency map (what's
first / parallel / blocked), running it accordingly." + a link to the folder with
the per-task PRDs.

## Notes
- The point: better than one PRD for everything — each piece is thought through and
  the order is known up front. Less rework.
- Use expensive models only for the analysis / map; the per-task PRDs are fine on a
  cheaper model.
