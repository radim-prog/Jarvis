---
description: Weekly review of accumulated user-memory — deduplicate, resolve contradictions, prune stale entries
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# /user-model-review — keep the user model honest

Inspired by Hermes Agent / Honcho — an agent that maintains a model of the user must periodically reconcile that model. Memories accumulate, contradict each other, and decay. Without review the agent drifts.

## When to use

- User explicitly asks: "review your memory", "what do you remember about me", "clean up your memory"
- Cron-style: once a week (Sunday evening or first session of the week)
- After a major life/work shift the user mentioned, to catch newly-stale memories
- When you notice you cited a memory that turned out wrong — review the surrounding ones

## Steps

1. **Inventory** — list all memory files for this project:
   ```bash
   ls -la ~/.claude/projects/<project>/memory/
   wc -l ~/.claude/projects/<project>/memory/MEMORY.md
   ```
   Note: MEMORY.md should stay under 200 lines (auto-loader truncates after that).

2. **Read MEMORY.md fully** + open every side file. Build a mental table: name, type, age (mtime), one-line summary.

3. **Find duplicates** — group by topic. Two `feedback_*` files about the same rule → merge. Two `user_*` files about the same trait → merge. Use `Grep` across the memory/ folder for overlap signals.

4. **Find contradictions** — if memory A says "always X" and memory B says "never X (in context Y)", the second one is a refinement. Edit A to point at B, or merge.

5. **Find stale entries** — for each memory:
   - Cite specific paths/files/people/projects? `Glob` / `Grep` to verify they still exist.
   - References a concrete date (e.g., "meeting on April 17")? Past dates → archive or delete.
   - Project memory referencing a state that has changed? Update or remove.
   - Session snapshots older than 30 days → delete (they're not load-bearing).

6. **Find gaps** — read last 7 days of jsonl sessions via `recall.py`:
   ```bash
   python3 ~/.claude/scripts/recall.py "feedback OR decided OR remember" --since $(date -d '7 days ago' +%Y-%m-%d) --role user --limit 30
   ```
   Each hit where the user gave guidance/correction → check if it's already in memory. If not, propose adding it.

7. **Update MEMORY.md index** — keep one-line entries, sorted semantically (user/feedback/project/reference grouped), under 200 lines. If over, demote less-important entries to side files only.

8. **Report** — present findings to user as a compact diff:
   ```
   Memory after review:
   - merged: feedback_X + feedback_Y → feedback_X (overlap)
   - dropped: session_2026-04-15_snapshot.md (28 days old)
   - updated: project_<example>.md (event passed, status updated)
   - new: feedback_Z (from sessions on 22-24 Apr)
   - conflict: feedback_A vs feedback_B — needs your decision
   ```

9. **Apply changes only after user confirms** — destructive ops (delete, merge) need a green light. Additions are OK to apply directly if the user already said it once and you have a session quote.

## Safety

- NEVER silently delete memory files — always present to user first.
- Preserve the **why** when merging — the rationale is the most expensive part to recover.
- Don't delete session snapshots if they reference open commitments. Verify first.
- If unsure whether a memory is stale, keep it and add a `**Verify:**` note instead.
- Memory files are append-much / edit-rarely. Heavy churn signals you're using memory for transient state — push that to plans/tasks instead.

## Cadence

Default schedule: weekly. Add to cron only after the user explicitly approves a fully-automated weekly run — by default this command runs interactively and asks for confirmation.
