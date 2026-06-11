#!/bin/bash
# key-monitor — sanity-check the API tokens your setup depends on.
#
# Each known credential is probed with a harmless read-only call. Anything that
# fails (expired token, revoked OAuth, dead bot) gets a single Telegram alert.
# Healthy keys are silent — same "silent green, loud red" idea as doctor_cron.py.
#
# Designed to be run from cron, e.g. once a day:
#   30 6 * * * /usr/local/bin/key-monitor.sh >/dev/null 2>&1
#
# Configuration via ~/.claude/secrets/.env (all optional — a check is skipped
# when its inputs are absent, so you only probe what you actually use):
#   TELEGRAM_BOT_TOKEN   = <bot token used to send the alert>
#   TELEGRAM_CHAT_ID     = <numeric chat id to receive alerts>
#   TELEGRAM_BOT_TOKENS  = CSV of extra bot tokens to verify via getMe
#   WAHA_API_KEY         = <waha key> (probes WAHA_URL, default localhost:3100)
#   WAHA_URL             = optional override of the WAHA sessions endpoint
# GitHub (via gh CLI) and Google OAuth (google_token.json) are auto-detected.

set -uo pipefail

SECRETS="${SECRETS:-$HOME/.claude/secrets/.env}"
GOOGLE_TOKEN="${GOOGLE_TOKEN:-$HOME/.claude/secrets/google_token.json}"
LOG="${KEY_MONITOR_LOG:-/tmp/key-monitor.log}"

# shellcheck disable=SC1090
[ -f "$SECRETS" ] && source "$SECRETS" 2>/dev/null || true

load_secret() {
  grep "^$1=" "$SECRETS" 2>/dev/null | cut -d= -f2- | tr -d '"'
}

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

alert() {
  local msg="$1"
  local token chat
  token=$(load_secret TELEGRAM_BOT_TOKEN)
  chat=$(load_secret TELEGRAM_CHAT_ID)
  if [ -z "$token" ] || [ -z "$chat" ]; then
    echo "[key-monitor] would-alert: $msg (TELEGRAM_BOT_TOKEN/CHAT_ID missing)" >&2
    return
  fi
  curl -sS -X POST "https://api.telegram.org/bot$token/sendMessage" \
    -d "chat_id=$chat" -d "text=$msg" >/dev/null || true
}

# 1) GitHub token — gh API call
if command -v gh >/dev/null 2>&1; then
  if gh api user --silent 2>/dev/null; then
    log "github: ok"
  else
    log "github: FAILED (gh api user)"
    alert "GitHub token broken — 'gh api user' failed. Re-run: gh auth login"
  fi
fi

# 2) Google OAuth (google_token.json) — Gmail getProfile is a harmless probe
if [ -f "$GOOGLE_TOKEN" ]; then
  result=$(GTOK="$GOOGLE_TOKEN" python3 - <<'PY' 2>&1
import os
try:
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    c = Credentials.from_authorized_user_file(os.environ["GTOK"])
    build("gmail", "v1", credentials=c).users().getProfile(userId="me").execute()
    print("OK")
except Exception as e:
    print(f"ERR: {e}")
PY
)
  if [ "$result" = "OK" ]; then
    log "google: ok"
  else
    log "google: FAILED ($result)"
    alert "Google OAuth token broken. Re-auth your google_token.json. ($result)"
  fi
fi

# 3) Telegram bot tokens — getMe on the alert bot plus any extras in CSV
TG_TOKENS="${TELEGRAM_BOT_TOKENS:-}"
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && TG_TOKENS="${TELEGRAM_BOT_TOKEN},${TG_TOKENS}"
IFS=',' read -ra _toks <<< "$TG_TOKENS"
for token in "${_toks[@]}"; do
  token="$(echo "$token" | tr -d ' "')"
  [ -z "$token" ] && continue
  bot_id="${token%%:*}"
  if curl -s "https://api.telegram.org/bot${token}/getMe" | grep -q '"ok":true'; then
    log "telegram_${bot_id}: ok"
  else
    log "telegram_${bot_id}: FAILED (getMe)"
    alert "Telegram bot ${bot_id} token failed getMe — reset it via @BotFather."
  fi
done

# 4) WAHA API (optional)
if [ -n "${WAHA_API_KEY:-}" ]; then
  url="${WAHA_URL:-http://127.0.0.1:3100/api/sessions}"
  if curl -s -H "X-Api-Key: ${WAHA_API_KEY}" "$url" | grep -qE 'name|status'; then
    log "waha: ok"
  else
    log "waha: FAILED ($url)"
    alert "WAHA API not responding at ${url} (container down or key expired)."
  fi
fi

log "sweep done"
