#!/usr/bin/env bash
# completion-gate.sh — PreToolUse hook enforcing the Definition of Done.
#
# When you report a DEPLOY / DONE claim about a feature to your human WITHOUT a
# screenshot attached, this reminds you of the 3 gates (see
# rules/definition-of-done.md). It never blocks legitimate comms — the reminder
# goes to stderr; the hard teeth live in the rule and the workflow phase.
#
# Wire it up in ~/.claude/settings.json as a PreToolUse hook on your outgoing
# message/reply tool, e.g.:
#   "PreToolUse": [{
#     "matcher": "mcp__<your_messaging_tool>__reply",
#     "hooks": [{ "type": "command",
#       "command": "$HOME/.claude/hooks/completion-gate.sh" }]
#   }]
#
# Configuration via environment (all optional):
#   GATE_REPLY_TOOL  = exact tool_name to gate on (default: any reply tool)
#   GATE_CHAT_ID     = only gate messages to this chat/recipient id (default: any)
#   GATE_LOG         = path to append claim events (default: this script's dir)

set -uo pipefail
INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || true)

# If GATE_REPLY_TOOL is set, only gate that exact tool. Otherwise gate anything
# whose name ends in 'reply' (covers most messaging integrations).
if [ -n "${GATE_REPLY_TOOL:-}" ]; then
  [ "$TOOL" != "$GATE_REPLY_TOOL" ] && exit 0
else
  case "$TOOL" in
    *reply) : ;;
    *) exit 0 ;;
  esac
fi

# Optionally scope to a single recipient (your own chat id).
if [ -n "${GATE_CHAT_ID:-}" ]; then
  CHAT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('chat_id',''))" 2>/dev/null || true)
  [ "$CHAT" != "$GATE_CHAT_ID" ] && exit 0
fi

PAYLOAD=$(echo "$INPUT" | python3 -c "
import sys,json
d=json.load(sys.stdin).get('tool_input',{})
text=(d.get('text') or '').lower()
files=d.get('files') or []
# completion / deploy claim keywords
kw=['deployed','is live','went live','go-live','go live','just shipped',
    'shipped it','done and deployed','it is now live','live in production',
    'pushed to prod','rolled out']
hit=any(k in text for k in kw)
print('HIT' if (hit and not files) else 'OK')
" 2>/dev/null || echo OK)

if [ "$PAYLOAD" = "HIT" ]; then
  echo "DEFINITION-OF-DONE: you are reporting a DEPLOY/done claim WITHOUT a screenshot." >&2
  echo "   Before you send it, clear the 3 gates (rules/definition-of-done.md):" >&2
  echo "   1) Reverse-check against the ORIGINAL assignment (independent model) — matrix done/deployed + %." >&2
  echo "   2) Tester click-through: the user REALLY sees it in the UI (not API 200 / flag)." >&2
  echo "   3) Attach a screenshot of the live feature (files: [...]) — the human shouldn't have to go check." >&2
  echo "   If this is just an interim status (not a fresh deploy to verify), continue." >&2
  LOG="${GATE_LOG:-$(dirname "${BASH_SOURCE[0]}")/completion-gate.log}"
  echo "$(date '+%F %T') COMPLETION-CLAIM-NO-SCREENSHOT" >> "$LOG" 2>/dev/null || true
fi
exit 0
