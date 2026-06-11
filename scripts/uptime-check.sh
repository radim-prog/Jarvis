#!/bin/bash
# uptime-check — poll a list of URLs and alert on state transitions.
#
# For each URL it records up/down state in a tiny SQLite db. It only sends a
# Telegram message when a site flips up->down or down->up (with the outage
# duration on recovery) — not on every run. Quiet hours suppress alerts to a
# log so you don't get pinged at night.
#
# Designed to be run from cron, e.g. hourly:
#   0 * * * * /usr/local/bin/uptime-check.sh >/dev/null 2>&1
#
# Configuration via ~/.claude/secrets/.env (or environment):
#   TELEGRAM_BOT_TOKEN   = <bot token for alerts>
#   TELEGRAM_CHAT_ID     = <numeric chat id>
#   HEALTH_URLS          = CSV of "host|label" entries, e.g.
#                          "example.com|Main site,api.example.com|API"
#                          (label is optional; falls back to the host)
#   QUIET_START          = hour to start quiet hours (default 22)
#   QUIET_END            = hour to end quiet hours (default 6)
#   UPTIME_DB            = SQLite path (default ~/.uptime-check.db)
#   UPTIME_TIMEOUT       = curl timeout seconds (default 15)

set -uo pipefail

SECRETS="${SECRETS:-$HOME/.claude/secrets/.env}"
# shellcheck disable=SC1090
[ -f "$SECRETS" ] && source "$SECRETS" 2>/dev/null || true

DB="${UPTIME_DB:-$HOME/.uptime-check.db}"
LOG="${UPTIME_LOG:-/tmp/uptime-check.log}"
TIMEOUT_SECS="${UPTIME_TIMEOUT:-15}"
QUIET_START="${QUIET_START:-22}"
QUIET_END="${QUIET_END:-6}"

load_secret() {
  grep "^$1=" "$SECRETS" 2>/dev/null | cut -d= -f2- | tr -d '"'
}

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

is_quiet_hours() {
  local h
  h=$(date +%H)
  # Handle ranges that wrap past midnight (e.g. 22..6).
  if [ "$QUIET_START" -le "$QUIET_END" ]; then
    [ "$h" -ge "$QUIET_START" ] && [ "$h" -lt "$QUIET_END" ]
  else
    [ "$h" -ge "$QUIET_START" ] || [ "$h" -lt "$QUIET_END" ]
  fi
}

alert() {
  local msg="$1"
  if is_quiet_hours; then
    log "QUIET-HOURS suppressed alert: $msg"
    return
  fi
  local token chat
  token=$(load_secret TELEGRAM_BOT_TOKEN)
  chat=$(load_secret TELEGRAM_CHAT_ID)
  if [ -z "$token" ] || [ -z "$chat" ]; then
    echo "[uptime-check] would-alert: $msg (TELEGRAM_BOT_TOKEN/CHAT_ID missing)" >&2
    return
  fi
  curl -sS -X POST "https://api.telegram.org/bot$token/sendMessage" \
    -d "chat_id=$chat" -d "text=$msg" >/dev/null || true
}

if [ -z "${HEALTH_URLS:-}" ]; then
  echo "[uptime-check] HEALTH_URLS not set — nothing to check." >&2
  echo "  Example: HEALTH_URLS=\"example.com|Main,api.example.com|API\"" >&2
  exit 0
fi

sqlite3 "$DB" <<'SQL' >/dev/null 2>&1
CREATE TABLE IF NOT EXISTS uptime_state (
  url TEXT PRIMARY KEY,
  label TEXT,
  current_state TEXT,        -- 'up' / 'down'
  state_since TEXT,
  last_check_ts TEXT,
  last_status_code INTEGER,
  total_outages INTEGER DEFAULT 0
);
SQL

# A 2xx/3xx/4xx response means the server is up (401/403 = app alive but gated).
# Only 5xx, timeouts and connection failures count as down.
is_ok_status() { [ "$1" -ge 200 ] && [ "$1" -lt 500 ]; }

check_url() {
  local host="$1"
  curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT_SECS" \
    "https://${host}" 2>/dev/null || echo "0"
}

log "sweep start"
IFS=',' read -ra _entries <<< "$HEALTH_URLS"
for entry in "${_entries[@]}"; do
  entry="$(echo "$entry" | sed 's/^ *//;s/ *$//')"
  [ -z "$entry" ] && continue
  URL="${entry%%|*}"
  LABEL="${entry##*|}"
  [ "$LABEL" = "$entry" ] && LABEL="$URL"

  CODE=$(check_url "$URL")
  if is_ok_status "$CODE"; then CURRENT="up"; else CURRENT="down"; fi

  PREV=$(sqlite3 "$DB" "SELECT current_state FROM uptime_state WHERE url='$URL';" 2>/dev/null)

  if [ -z "$PREV" ]; then
    sqlite3 "$DB" "INSERT INTO uptime_state (url,label,current_state,state_since,last_check_ts,last_status_code) VALUES ('$URL','$LABEL','$CURRENT',datetime('now'),datetime('now'),$CODE);"
    log "[first] $URL -> $CURRENT (HTTP $CODE)"
    continue
  fi

  if [ "$CURRENT" != "$PREV" ]; then
    if [ "$CURRENT" = "down" ]; then
      sqlite3 "$DB" "UPDATE uptime_state SET current_state='down',state_since=datetime('now'),last_check_ts=datetime('now'),last_status_code=$CODE,total_outages=total_outages+1 WHERE url='$URL';"
      log "[DOWN] $URL HTTP $CODE"
      alert "🔴 $LABEL ($URL) DOWN — HTTP $CODE."
    else
      DOWN_SINCE=$(sqlite3 "$DB" "SELECT state_since FROM uptime_state WHERE url='$URL';" 2>/dev/null)
      DURATION_MIN=$(( ( $(date +%s) - $(date -d "$DOWN_SINCE" +%s 2>/dev/null || date +%s) ) / 60 ))
      sqlite3 "$DB" "UPDATE uptime_state SET current_state='up',state_since=datetime('now'),last_check_ts=datetime('now'),last_status_code=$CODE WHERE url='$URL';"
      log "[UP] $URL after ${DURATION_MIN} min"
      alert "🟢 $LABEL ($URL) UP — outage lasted ${DURATION_MIN} min."
    fi
  else
    sqlite3 "$DB" "UPDATE uptime_state SET last_check_ts=datetime('now'),last_status_code=$CODE WHERE url='$URL';"
  fi
done
log "sweep done"
