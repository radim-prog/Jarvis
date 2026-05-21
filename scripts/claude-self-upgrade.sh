#!/bin/bash
# claude-self-upgrade — restart this Claude Code session into a fresh process
# so it picks up a newer Claude Code binary.
#
# Sends Ctrl-C twice with a short pause (Claude Code's interrupt protocol),
# captures the existing session ID from the screen, then re-launches
# `claude --resume <sid>` with the original flags.
#
# Run from an `at` job or another tmux pane — running it from the same
# session it's trying to upgrade will deadlock.
#
# Usage: claude-self-upgrade.sh <tmux-session>
#
# Env knobs:
#   PROJECT_DIR        = working dir for the new claude invocation
#   CLAUDE_EXTRA_FLAGS = extra flags to append (e.g. --channels ...)
#   COMPACT_FIRST=1    = run /compact before upgrading (recommended)

set -uo pipefail

SESS="${1:?usage: $0 <tmux-session>}"

if ! tmux has-session -t "$SESS" 2>/dev/null; then
  echo "tmux session '$SESS' not found" >&2
  exit 1
fi

if [ "${COMPACT_FIRST:-1}" = "1" ]; then
  tmux send-keys -t "$SESS" '/compact' Enter
  sleep 90
fi

# Two Ctrl-Cs to exit the session
tmux send-keys -t "$SESS" C-c
sleep 0.3
tmux send-keys -t "$SESS" C-c
sleep 8

# Find the session ID Claude Code prints on exit:
#   Resume this session with:  claude --resume <uuid>
sid=$(tmux capture-pane -p -t "$SESS" -S -10 | grep -oE 'claude --resume [a-f0-9-]+' | tail -1 | awk '{print $3}')
if [ -z "$sid" ]; then
  echo "no resume session ID found on screen — aborting" >&2
  exit 2
fi

cd_part=""
if [ -n "${PROJECT_DIR:-}" ]; then
  cd_part="cd $PROJECT_DIR && "
fi

cmd="${cd_part}claude --resume $sid ${CLAUDE_EXTRA_FLAGS:-} --dangerously-skip-permissions"
tmux send-keys -t "$SESS" "$cmd" Enter
sleep 12
# Some screens prompt to confirm "Resume from summary?" — press Enter again
tmux send-keys -t "$SESS" Enter
sleep 4
echo "$SESS upgrade dispatched (sid=$sid)"
