# Definition of Done — 3 enforceable gates

When a big task is claimed "done", it usually isn't. The most common failure mode
is an agent that builds a clean backend, skips the part the user actually sees, and
sends no proof. The cause: the usual checks only guard *code correctness*, not
*completion of the original ask* + *visibility to the user*. These three gates fix
that. They are **gates, not suggestions** — nothing ships until all three pass.

## No non-trivial / multi-step task is "DONE" until it has cleared ALL 3 gates:

### Gate 1 — Reverse-check against the ORIGINAL assignment
- Before anyone says "done", an **independent reviewer (a different model than the
  author)** compares the result against the ORIGINAL assignment — the recording /
  spec / PRD itself, re-read in full, **not** a plan derived from it.
- Output: a matrix of *every* item in the assignment →
  `[done + deployed + visible / coded-but-not-deployed / missing]`, plus a rough
  completion % weighted by the user's stated priorities.
- Watch for plan-drift: the plan should already be checked against the assignment
  *at planning time* (so it doesn't quietly settle for the easy backend and drop
  the user's #1 priority). Gate 1 applies to the plan too.

### Gate 2 — Visible and usable by the USER (not backend / API)
- "Deployed / done" means the end user actually **sees** it in the real UI (in the
  navigation, reachable on a route, on real data) and can **use** it. Not "the API
  returns 200" and not "the flag is on".
- This is verified by a **Tester clicking through the live deployed app as that
  user** — not the author, not a smoke-test against an endpoint. If the Tester
  can't find it in the UI, it is NOT done.

### Gate 3 — Visual proof to the human
- After each milestone deploy, the Tester opens the thing in a browser, takes a
  **screenshot of the real deployed feature**, and **the screenshot reaches the
  human alongside the milestone report**. The human should not have to go digging
  through the app to check whether something that was claimed actually exists —
  the proof comes to them.
- No screenshot → "deployed" is not reported to the human.

## Enforcement
- Hook `hooks/completion-gate.sh` (PreToolUse on the message-reply tool): when an
  outgoing message claims "done / deployed / live / go-live" about a feature or
  deploy *without an attached screenshot*, it reminds/requires the 3 gates +
  screenshot. Without proof: hold and complete it first.
- In `/team` and any orchestrated workflow: a final phase of "reverse verification
  + visual proof" is **mandatory** and cannot be skipped, otherwise the task is
  not closed.
- The orchestrator does NOT report "done" to the human without its own spot-check
  of all 3 gates.
