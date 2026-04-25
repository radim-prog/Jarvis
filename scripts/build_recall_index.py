#!/usr/bin/env python3
"""Build FTS5 index of past Claude Code sessions.

Walks ~/.claude/projects/**/*.jsonl, extracts user+assistant message text,
stores in SQLite FTS5 for fast full-text recall.

Usage: python3 build_recall_index.py [--full]
  --full  : rebuild from scratch (default: incremental, skip already-indexed sessions)
"""
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

DB = Path.home() / ".claude" / "recall.db"
ROOT = Path.home() / ".claude" / "projects"


def init_db(con: sqlite3.Connection) -> None:
    con.executescript("""
        CREATE VIRTUAL TABLE IF NOT EXISTS messages USING fts5(
            project, session_id, role, ts, content,
            tokenize='unicode61 remove_diacritics 2'
        );
        CREATE TABLE IF NOT EXISTS indexed_files(
            path TEXT PRIMARY KEY,
            mtime REAL NOT NULL,
            messages INTEGER NOT NULL DEFAULT 0,
            indexed_at REAL NOT NULL
        );
    """)


def extract_text(msg) -> str:
    """Pull plain text out of a message.content field (string or list of blocks)."""
    if isinstance(msg, str):
        return msg
    if isinstance(msg, list):
        parts = []
        for b in msg:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "text":
                parts.append(b.get("text", ""))
            elif b.get("type") == "tool_use":
                parts.append(f"[tool:{b.get('name','')}]")
            elif b.get("type") == "tool_result":
                c = b.get("content")
                if isinstance(c, str):
                    parts.append(c[:2000])
                elif isinstance(c, list):
                    for x in c:
                        if isinstance(x, dict) and x.get("type") == "text":
                            parts.append(x.get("text", "")[:2000])
        return "\n".join(parts)
    return ""


def index_file(con: sqlite3.Connection, path: Path) -> int:
    """Index a single jsonl, return count of messages added."""
    project = path.parent.name
    n = 0
    with path.open("r", errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get("type")
            if t not in ("user", "assistant"):
                continue
            m = d.get("message") or {}
            text = extract_text(m.get("content"))
            if not text or len(text) < 4:
                continue
            con.execute(
                "INSERT INTO messages(project, session_id, role, ts, content) VALUES(?,?,?,?,?)",
                (project, d.get("sessionId") or path.stem, m.get("role", t), d.get("timestamp", ""), text[:8000]),
            )
            n += 1
    return n


def main():
    full = "--full" in sys.argv
    con = sqlite3.connect(DB)
    init_db(con)
    if full:
        con.execute("DELETE FROM messages")
        con.execute("DELETE FROM indexed_files")
        con.commit()

    indexed = {row[0]: row[1] for row in con.execute("SELECT path, mtime FROM indexed_files")}
    files = sorted(ROOT.rglob("*.jsonl"))
    total_added = 0
    skipped = 0
    started = time.time()
    for p in files:
        sp = str(p)
        mtime = p.stat().st_mtime
        if not full and indexed.get(sp) == mtime:
            skipped += 1
            continue
        # purge old rows for this file before re-indexing
        con.execute("DELETE FROM messages WHERE session_id=?", (p.stem,))
        n = index_file(con, p)
        con.execute(
            "INSERT OR REPLACE INTO indexed_files(path,mtime,messages,indexed_at) VALUES(?,?,?,?)",
            (sp, mtime, n, time.time()),
        )
        total_added += n
    con.commit()
    elapsed = time.time() - started
    rows = con.execute("SELECT COUNT(*) FROM messages").fetchone()[0]
    print(f"indexed {len(files) - skipped} files ({skipped} unchanged), +{total_added} msgs, total {rows} rows, {elapsed:.1f}s")
    con.close()


if __name__ == "__main__":
    main()
