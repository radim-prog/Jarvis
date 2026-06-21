# gmail-send — CLI helper for sending email via Gmail API

`gmail-send` is a globally-installed Python helper that uses your OAuth token
(`~/.claude/secrets/google_token.json`, scope `gmail.modify`) to send email
directly through the Gmail API. Works from any Claude Code session, including
sessions wired to a messaging integration via the channels plugin.

## When to use

- User explicitly asks to send an email
- Sending a notification about a completed long-running task, pipeline error,
  or monitoring result
- Async summary report for a deploy / experiment / setup run
- **NOT** for draft-only scenarios — for drafts that need human review before
  sending, use the Gmail MCP connector (`mcp__claude_ai_Gmail__create_draft`)
  so the draft appears in the Gmail web UI for approval.

## Binary location

```
$HOME/.claude/secrets/gmail_send.py   # source
/usr/local/bin/gmail-send              # symlink (on PATH)
```

Env var (set in secrets): `GMAIL_SEND_SCRIPT=$HOME/.claude/secrets/gmail_send.py`

## Usage

### 1) Inline body (simplest)

```bash
gmail-send --to user@example.com --subject "Hello" --body "Message body"
```

### 2) Body from file

```bash
gmail-send --to user@example.com --subject "Report" --body-file /tmp/report.txt
```

### 3) Body from stdin (heredoc friendly)

```bash
gmail-send --to user@example.com --subject "Log" --body-file - <<'EOF'
Multi-line
text with no escaping issues.
EOF
```

### 4) HTML

```bash
gmail-send --to user@example.com --subject "HTML report" --body-file report.html --html
```

### 5) JSON stdin (for long / complex messages — no shell escaping)

```bash
echo '{"to":"user@example.com","subject":"Test","body":"<b>hi</b>","html":true,"cc":"other@example.com"}' | gmail-send --json
```

JSON schema:
```json
{
  "to":        "required, comma-separated for multiple recipients",
  "subject":   "required",
  "body":      "required",
  "cc":        "optional",
  "bcc":       "optional",
  "html":      "optional bool, default false",
  "from_name": "optional display name",
  "dry_run":   "optional bool, default false"
}
```

### 6) Dry-run (for testing)

```bash
gmail-send --to user@example.com --subject "test" --body "test" --dry-run
```

Returns JSON without actually sending — useful to verify arg parsing.

## Output

Stdout: JSON result. On success:
```json
{
  "ok": true,
  "id": "19d7ce7c398f394c",
  "threadId": "19d7ce7c398f394c",
  "labelIds": ["SENT"],
  "to": "...",
  "subject": "..."
}
```

On error, stderr receives:
```json
{"ok": false, "error": "error description"}
```

Exit code: 0 OK, 1 error, 2 missing libs.

## Recommended workflow for long / HTML emails

To safely send long content without shell escape issues:

1. Write the body to a file (`/tmp/email-body.html`)
2. Call: `gmail-send --to ... --subject "..." --body-file /tmp/email-body.html --html`
3. Clean up: `rm /tmp/email-body.html`

Or via JSON stdin + heredoc:
```bash
python3 -c "import json; print(json.dumps({'to':'...','subject':'...','body':open('/tmp/body.html').read(),'html':True}))" | gmail-send --json
```

## What NOT to send

- Tokens, passwords, API keys, or production secrets
- Personal data without a clear reason
- Automated notifications without explicit user consent (except pre-agreed pipelines)
- For production changes, payments, or data deletion — always ask first

## Troubleshooting

If `gmail-send` reports an error:

- **`token file not found`** → run `python3 $HOME/.claude/secrets/google_auth.py`
  (interactive OAuth flow on port 8085)
- **`HttpError 401` / Unauthorized** → token expired, refresh failed. Re-auth
  via `google_auth.py`.
- **`HttpError 403` / Forbidden** → scope issue. Check that `gmail.modify` is
  in the `scopes` field in `google_token.json`.
- **`missing google libs`** → `pip3 install google-auth google-api-python-client google-auth-oauthlib`

## Related

- `gdrive.py` — Google Drive helper (lives alongside `gmail_send.py`)
- `google_auth.py` — OAuth token generator (run interactively when token expires)
- Gmail MCP tools — `create_draft`, `search_threads`, etc. (read/draft, not send)
