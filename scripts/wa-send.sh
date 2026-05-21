#!/bin/bash
# wa-send — send a WhatsApp message via a WAHA container.
#
# WAHA (https://waha.devlike.pro/) provides a HTTP API in front of the
# WhatsApp web client. This wrapper hides the curl boilerplate.
#
# Usage:
#   wa-send.sh 420XXXXXXXXX "text"
#   echo "text" | wa-send.sh 420XXXXXXXXX -
#
# Configuration (env or ~/.claude/secrets/.env):
#   WAHA_API_KEY     = your WAHA api key (required)
#   WAHA_BASE_URL    = http://127.0.0.1:3100  (default if WAHA runs locally)
#   WAHA_SESSION     = default
#
# Exit code: 0 success, 1 bad args, 2 WAHA error.

set -euo pipefail

PHONE="${1:-}"
TEXT="${2:-}"

if [ -z "$PHONE" ]; then
  echo "usage: $0 <phone-420xxxxxxxxx> <text|->" >&2
  exit 1
fi

if [ "$TEXT" = "-" ]; then
  TEXT="$(cat)"
fi

if [ -z "$TEXT" ]; then
  echo "error: empty message text" >&2
  exit 1
fi

if [[ ! "$PHONE" =~ ^[0-9]{10,15}$ ]]; then
  echo "error: phone must be digits-only including country code, e.g. 420XXXXXXXXX" >&2
  exit 1
fi

SECRETS="${SECRETS:-$HOME/.claude/secrets/.env}"
WAHA_KEY="${WAHA_API_KEY:-}"
if [ -z "$WAHA_KEY" ] && [ -f "$SECRETS" ]; then
  WAHA_KEY=$(grep "^WAHA_API_KEY=" "$SECRETS" | cut -d= -f2-)
fi
if [ -z "$WAHA_KEY" ]; then
  echo "error: WAHA_API_KEY missing" >&2
  exit 2
fi

WAHA_BASE_URL="${WAHA_BASE_URL:-http://127.0.0.1:3100}"
WAHA_SESSION="${WAHA_SESSION:-default}"

TEXT_JSON=$(printf '%s' "$TEXT" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read()))')
PAYLOAD=$(printf '{"session":"%s","chatId":"%s@c.us","text":%s}' "$WAHA_SESSION" "$PHONE" "$TEXT_JSON")

RESPONSE=$(curl -sS -f -m 10 -X POST \
  -H "X-Api-Key: ${WAHA_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WAHA_BASE_URL/api/sendText" 2>&1) || {
  echo "error: WAHA call failed: $RESPONSE" >&2
  exit 2
}

if echo "$RESPONSE" | grep -q '"id"'; then
  echo "$RESPONSE"
  exit 0
else
  echo "error: WAHA response: $RESPONSE" >&2
  exit 2
fi
