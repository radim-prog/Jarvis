---
description: Quick health check of Claude Code environment — secrets, MCP, services, processes
allowed-tools: Bash, Read
---

# /doctor — Claude Code health check

Inspired by Hermes Agent (Nous Research). When the user suspects something is broken or before starting a long autonomous run, /doctor returns a one-screen status of everything that matters.

## When to use

- User says "what's broken", "check yourself", "anything failing"
- Before starting an autonomous task (long-running agent, supervisor mode)
- After a fresh install or restart
- When a tool unexpectedly fails — check if it's a config issue first

## Steps

Run all checks in parallel via single Bash block. Report as compact table grouped by category. Mark each line: ✓ OK / ⚠ WARN / ✗ FAIL with one-line reason.

### 1. Secrets & env
- `~/.claude/secrets/.env` exists and is readable
- Count of keys present (don't print values)
- Critical keys present: `ANTHROPIC_API_KEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `TELEGRAM_BOT_TOKEN` (and any others your setup requires)

### 2. CLI auth
- `gh auth status` — GitHub login OK?
- Google token: `~/.claude/secrets/google_token.json` exists, not expired
- Other CLI tools your stack depends on (`vercel whoami`, etc.)

### 3. MCP servers
- Read `~/.claude/.mcp.json` (NOT settings.json — MCP config lives there)
- `python3 -c "import json; s=json.load(open('/root/.claude/.mcp.json')); print(len(s.get('mcpServers',{})), 'configured'); [print(f'  {k}') for k in s.get('mcpServers',{})]"`
- For each: probe is process running / endpoint reachable

### 4. Background services
- Telegram bot: `pgrep -f "telegram"` and last log line
- WAHA WhatsApp: `curl -s -H "X-Api-Key: $WAHA_API_KEY" http://127.0.0.1:3100/api/sessions` (adjust if your WAHA runs elsewhere)
- Postgres: `pg_isready -h localhost -p 5432` (or whichever port your stack uses)
- Other binaries on PATH that your stack expects

### 5. tmux sessions
- `tmux ls` — list active sessions, flag any > 7 days old (likely stale)

### 6. Disk & memory
- `df -h /` (warn if > 85% full)
- `free -h` (warn if available < 1G)
- `~/.claude/projects/` size (memory bloat indicator)

### 7. Recent errors
- Tail last 20 lines of `~/.claude/logs/` (if exists) — flag any ERROR/FATAL

## Output format

```
=== Claude Code health ===
Secrets:    ✓ N keys, all critical present
GitHub:     ✓ <handle> logged in
Google:     ⚠ token expires in 3 days
MCP:        ✓ N servers configured, M reachable
Telegram:   ✓ bot running (pid 1234, last msg 2m ago)
WAHA:       ✗ unreachable (connection refused)
Postgres:   ✓ accepting connections
tmux:       ✓ N sessions, none stale
Disk:       ✓ 42% used
Memory:     ✓ 4.2G available
Errors:     ✓ no fatal errors in last hour
```

End with one-line verdict: `Healthy.` / `Degraded — N issues.` / `Broken — fix before continuing.`

## Automation

The companion script `scripts/doctor_cron.py` runs the same checks non-interactively for cron. Suggested entry:

```cron
55 5 * * * /usr/bin/python3 /root/.claude/scripts/doctor_cron.py >/tmp/doctor.log 2>&1
```

Set `TELEGRAM_CHAT_ID` in `~/.claude/secrets/.env` to receive alerts when something fails. Healthy runs are silent.

## Safety

- NEVER print secret values (only "present" / "missing")
- Don't write anything; this command is READ-ONLY
- If a check itself fails (network, command not found), report it as ⚠ not crash
