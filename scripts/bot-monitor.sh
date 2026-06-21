#!/bin/bash
# bot-monitor — detect stuck Claude Code instances running in tmux.
#
# For each bot, capture the last lines of its tmux pane and hash them.
# If the hash hasn't changed across N consecutive runs while the bot has
# an active task in the queue, alert via Telegram.
#
# Designed to be run from cron, e.g. every 5 minutes:
#   */5 * * * * /usr/local/bin/bot-monitor.sh >/dev/null 2>&1
#
# Configuration via ~/.claude/secrets/.env:
#   TELEGRAM_BOT_TOKEN   = <bot token for alerts>
#   TELEGRAM_CHAT_ID     = <your chat id>
#
# Bots are described in BOT_LIST below — name and tmux session.

set -uo pipefail

SECRETS="${SECRETS:-$HOME/.claude/secrets/.env}"
STATE_DIR="${STATE_DIR:-$HOME/.bot-monitor}"
IDLE_THRESHOLD="${IDLE_THRESHOLD:-2}"  # alert after this many idle cycles
mkdir -p "$STATE_DIR"

# Bot list: "name:tmux-session" — edit to match your tmux session names.
# Each entry is "display-name:tmux-session-name".
BOT_LIST=(
  "WorkerA:worker-api"
  "WorkerB:worker-web"
)

# Optional: only alert when bot has an active task in some database.
# Set TASK_DB env to enable; the SQL below should return >0 if bot is busy.
TASK_DB="${TASK_DB:-}"

load_secret() {
  grep "^$1=" "$SECRETS" 2>/dev/null | cut -d= -f2- | tr -d '"'
}

alert() {
  local msg="$1"
  local token chat
  token=$(load_secret TELEGRAM_BOT_TOKEN)
  chat=$(load_secret TELEGRAM_CHAT_ID)
  if [ -z "$token" ] || [ -z "$chat" ]; then
    echo "[bot-monitor] would-alert: $msg (TELEGRAM_BOT_TOKEN/CHAT_ID missing)" >&2
    return
  fi
  curl -sS -X POST "https://api.telegram.org/bot$token/sendMessage" \
    -d "chat_id=$chat" -d "text=$msg" >/dev/null || true
}

check_bot() {
  local name="$1"
  local session="$2"
  local state_file="$STATE_DIR/$name.last"
  local idle_file="$STATE_DIR/$name.idle"

  if [ -n "$TASK_DB" ]; then
    local has_task
    has_task=$(sqlite3 "$TASK_DB" "SELECT COUNT(*) FROM tasks WHERE assigned_to='$name' AND status='in_progress'" 2>/dev/null)
    if [ "${has_task:-0}" = "0" ]; then
      echo "0" > "$idle_file"
      return
    fi
  fi

  local current
  current=$(tmux capture-pane -t "$session" -p 2>/dev/null | tail -5 | md5sum | awk '{print $1}')
  [ -z "$current" ] && return

  local previous
  previous=$(cat "$state_file" 2>/dev/null || echo "none")
  echo "$current" > "$state_file"

  if [ "$current" = "$previous" ]; then
    local idle_count
    idle_count=$(cat "$idle_file" 2>/dev/null || echo 0)
    idle_count=$((idle_count + 1))
    echo "$idle_count" > "$idle_file"

    if [ "$idle_count" -ge "$IDLE_THRESHOLD" ]; then
      local last_line
      last_line=$(tmux capture-pane -t "$session" -p 2>/dev/null | grep -v "^$" | tail -1 | head -c 200)
      alert "MONITOR: $name idle for ${idle_count} cycles. Last: $last_line"
    fi
  else
    echo "0" > "$idle_file"
  fi
}

for entry in "${BOT_LIST[@]}"; do
  name="${entry%%:*}"
  session="${entry#*:}"
  check_bot "$name" "$session"
done
