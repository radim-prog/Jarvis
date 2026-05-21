# Gmail send — univerzální CLI pro posílání e-mailů

Na tomto stroji je k dispozici **`gmail-send`** — globálně nainstalovaný Python helper, který používá uživatelův OAuth token (`~/.claude/secrets/google_token.json`, scope `gmail.modify`) pro posílání e-mailů přímo z Gmail API. Funguje z jakékoli Claude Code instance, včetně sessions napojených na Telegram bota přes channels plugin.

## Kdy použít

- Uživatel tě výslovně požádá o odeslání e-mailu
- Potřebuješ poslat notifikaci o dokončení dlouhého taska, chybě v pipeline, výsledku monitoringu
- Reportuj stav experimentu / setupu / deployu jako asynchronní shrnutí
- NEPOUŽÍVEJ pro draft-only scénáře — na to má Claude.ai vestavěný Gmail MCP connector (`mcp__claude_ai_Gmail__gmail_create_draft`). Ten nemá `send` — ale pro tvorbu draftů které si uživatel zkontroluje je lepší, protože se zobrazí v Gmail webu.

## Binární umístění

```
$HOME/.claude/secrets/gmail_send.py   # zdroj
/usr/local/bin/gmail-send              # symlink (na PATH)
```

Env var v secrets: `GMAIL_SEND_SCRIPT=$HOME/.claude/secrets/gmail_send.py`

## Použití

### 1) Inline body (nejjednodušší)

```bash
gmail-send --to user@example.com --subject "Ahoj" --body "Text zprávy"
```

### 2) Body ze souboru

```bash
gmail-send --to user@example.com --subject "Report" --body-file /tmp/report.txt
```

### 3) Body ze stdin (heredoc friendly)

```bash
gmail-send --to user@example.com --subject "Log" --body-file - <<'EOF'
Víceřádkový
text bez escape problémů.
EOF
```

### 4) HTML

```bash
gmail-send --to user@example.com --subject "HTML report" --body-file report.html --html
```

### 5) JSON stdin (pro dlouhé/komplexní zprávy — bez shell escape)

```bash
echo '{"to":"user@example.com","subject":"Test","body":"<b>hi</b>","html":true,"cc":"other@example.com"}' | gmail-send --json
```

JSON schema:
```json
{
  "to":        "required, comma-separated pro víc recipientů",
  "subject":   "required",
  "body":      "required",
  "cc":        "optional",
  "bcc":       "optional",
  "html":      "optional bool, default false",
  "from_name": "optional display name",
  "dry_run":   "optional bool, default false"
}
```

### 6) Dry-run (pro testování)

```bash
gmail-send --to user@example.com --subject "test" --body "test" --dry-run
```

Vrátí JSON bez skutečného odeslání — užitečné pro ověření že arg parsing funguje.

## Výstup

Stdout: JSON s výsledkem. Při úspěchu:
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

Při chybě stderr dostane:
```json
{"ok": false, "error": "popis chyby"}
```

Exit code: 0 OK, 1 chyba, 2 missing libs.

## Doporučený workflow pro dlouhé/HTML e-maily

Pro bezpečné posílání dlouhého obsahu bez shell escape hell:

1. Zapiš body do souboru (`/tmp/email-body.html`)
2. Zavolej: `gmail-send --to ... --subject "..." --body-file /tmp/email-body.html --html`
3. Smaž temp: `rm /tmp/email-body.html`

Nebo přes JSON stdin + heredoc:
```bash
python3 -c "import json; print(json.dumps({'to':'...','subject':'...','body':open('/tmp/body.html').read(),'html':True}))" | gmail-send --json
```

## Co NEPOSÍLEJ

- Tokeny, hesla, API klíče, produkční secrets
- Osobní údaje bez jasného důvodu
- Automatické notifikace bez explicitního souhlasu uživatele (kromě předem dohodnutých pipelines)
- Pro produkční změny, platby, smazání dat se VŽDY nejprve zeptej uživatele

## Obnova / troubleshooting

Pokud `gmail-send` hlásí chybu:

- **`token file not found`** → spusť `python3 $HOME/.claude/secrets/google_auth.py` (interaktivní OAuth flow na portu 8085)
- **`HttpError 401` / Unauthorized** → token expiroval, refresh selhal. Re-auth přes google_auth.py.
- **`HttpError 403` / Forbidden** → scope issue. Ověř že `gmail.modify` je v `scopes` pole v `google_token.json`.
- **`missing google libs`** → `pip3 install google-auth google-api-python-client google-auth-oauthlib`

## Související

- `gdrive.py` — Google Drive helper (existující, vedle gmail_send.py)
- `google_auth.py` — OAuth token generátor (spustí se interaktivně když token expiruje)
- `mcp__claude_ai_Gmail__*` — Claude.ai Gmail MCP (draft, read, search — NE send)
