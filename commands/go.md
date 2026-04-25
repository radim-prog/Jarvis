---
description: Ship the current task end-to-end — verify, simplify, then PR
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Task
---

# /go — verify → simplify → PR

Inspired by Boris Cherny's personal `/go` composite. Run only after a non-trivial code change passes typecheck/build/tests and you're about to claim "done". Triggers a three-stage gate: confirm correctness, polish what changed, ship to a pull request.

## When to use

- After completing a non-trivial code change (multi-file, new feature, bug fix that touches business logic).
- Typecheck / build / tests must already be green before running `/go`.
- Skip for trivial fixes (typo, single-line config) or for read-only tasks.

## When NOT to use

- Failing typecheck / build / tests — fix them first.
- Outside a git repo, or when no `gh` remote is configured (run only the verify+simplify stages, ship manually).
- The user is mid-discussion and hasn't approved the change.

## Steps

### 1. Verify
- Run typecheck, build, lint, tests for the language/framework in use.
- For web apps: spin the dev server, hit the touched endpoints with `curl`, watch for unexpected status codes.
- If anything fails: STOP. Don't proceed to simplify or ship. Report the failure.

### 2. Simplify
- Limit scope to files changed in this task — don't drift into unrelated cleanup.
- If a `/simplify` slash command or `pr-review-toolkit:code-simplifier` agent is available, delegate.
- Otherwise: re-read the diff and trim dead branches, redundant comments, and over-clever abstractions.

### 3. Ship
- `git add -p` the relevant hunks (avoid `git add .`).
- Commit using the project's existing style (look at last 5 commits via `git log --oneline`).
- Push to the current branch.
- `gh pr create` with `## Summary` + `## Test plan` body. Use a HEREDOC.

## Safety

- NEVER push directly to `main` / `master`. Confirm branch first.
- NEVER skip hooks (`--no-verify`, `--no-gpg-sign`) unless explicitly told.
- If verify fails, abort the entire flow — do not patch and re-run silently.
- Don't amend a previously published commit; create a new one.
