---
description: Search past Claude Code sessions via FTS5 — find when something was discussed/decided
allowed-tools: Bash
---

# /recall — full-text search across all past Claude sessions

Inspired by Hermes Agent's session memory. Indexes ~/.claude/projects/**/*.jsonl into a SQLite FTS5 db so you can answer "when did we discuss X" / "what did we decide about Y" without re-reading every conversation.

## When to use

- User asks "when did we work on this" / "remind me about X" / "what did we decide"
- Before starting a new task, check if it overlaps with prior work
- When something looks familiar but the auto-memory doesn't have it (memory holds *conclusions*, recall holds *full text*)
- When debugging why something is set up a certain way — search for the original decision

## Steps

1. Pass the user's question (or distilled keywords) to the recall script:
   ```bash
   python3 ~/.claude/scripts/recall.py "<query>" [--limit N] [--since YYYY-MM-DD] [--project <substring>] [--role user|assistant]
   ```
2. FTS5 supports `AND`, `OR`, `NEAR(a b, 5)`, `"quoted phrases"`, prefix `term*`. Use them to narrow.
3. If the index is stale or missing, rebuild first: `python3 ~/.claude/scripts/build_recall_index.py` (incremental — only new/modified jsonls). Use `--full` for a fresh wipe.
4. Output is one line per hit: `timestamp  role  project  session_id  snippet`. Pick a session_id to dive deeper:
   ```bash
   ls /root/.claude/projects/*/<session_id>.jsonl
   ```
5. Summarize hits for the user — don't dump raw output.

## Examples

```bash
# When did we set up service X?
python3 ~/.claude/scripts/recall.py "service-x AND setup" --limit 5

# What did the user say this month?
python3 ~/.claude/scripts/recall.py "decision" --since 2026-04-01 --role user

# Hits in a single project only
python3 ~/.claude/scripts/recall.py "topic" --project my-project
```

## Maintenance

- Incremental refresh is fast (<5s if nothing changed). Full rebuild ~50s for ~2k sessions on a typical workstation.
- Suggested cron: `*/15 * * * * /usr/bin/python3 /root/.claude/scripts/build_recall_index.py >/dev/null 2>&1` — incremental refresh every 15 min.
- DB lives at `~/.claude/recall.db`. Safe to delete and rebuild — no source of truth, just an index.

## Safety

- READ-ONLY operation — recall.py never writes anywhere except the index db.
- Snippet is truncated; if user needs the full message, open the jsonl by session_id.
- Don't leak raw snippets containing tokens/secrets — if a hit looks sensitive, redact before quoting.
