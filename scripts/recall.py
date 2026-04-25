#!/usr/bin/env python3
"""Query the FTS5 recall index.

Usage:
  recall.py "search terms"                  # default 10 hits
  recall.py "search terms" --limit 25
  recall.py "search terms" --since 2026-04-01
  recall.py "search terms" --project Notion
  recall.py "search terms" --role user
"""
import argparse
import sqlite3
import sys
from pathlib import Path

DB = Path.home() / ".claude" / "recall.db"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query", nargs="+", help="FTS5 query (supports AND/OR/NEAR/quoted phrases)")
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--since", default=None, help="ISO date YYYY-MM-DD")
    ap.add_argument("--project", default=None, help="substring of project folder name")
    ap.add_argument("--role", choices=["user", "assistant"], default=None)
    ap.add_argument("--snippet-len", type=int, default=180)
    args = ap.parse_args()

    if not DB.exists():
        print("recall.db missing — run: python3 ~/.claude/scripts/build_recall_index.py", file=sys.stderr)
        sys.exit(2)

    q = " ".join(args.query)
    con = sqlite3.connect(DB)
    where = ["messages MATCH ?"]
    params = [q]
    if args.since:
        where.append("ts >= ?")
        params.append(args.since)
    if args.project:
        where.append("project LIKE ?")
        params.append(f"%{args.project}%")
    if args.role:
        where.append("role = ?")
        params.append(args.role)
    sql = f"""
        SELECT ts, role, project, session_id,
               snippet(messages, 4, '«', '»', '…', 12) AS snip
        FROM messages
        WHERE {' AND '.join(where)}
        ORDER BY rank
        LIMIT ?
    """
    params.append(args.limit)

    rows = con.execute(sql, params).fetchall()
    if not rows:
        print("(no hits)")
        return
    for ts, role, project, sid, snip in rows:
        proj_short = project.replace("-root-Projects-", "").replace("-root-", "")[:30]
        print(f"{ts[:16]}  {role:9}  {proj_short:30}  {sid[:8]}  {snip}")


if __name__ == "__main__":
    main()
