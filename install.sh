#!/usr/bin/env bash
# install.sh — copy Jarvis files into ~/.claude/, build recall index, suggest cron
set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}/.claude"

echo "Installing Jarvis from ${SOURCE} into ${TARGET}"

mkdir -p "${TARGET}/commands" "${TARGET}/rules" "${TARGET}/scripts" \
         "${TARGET}/hooks" "${TARGET}/skills/decompose"

cp -v "${SOURCE}/commands/"*.md          "${TARGET}/commands/"
cp -v "${SOURCE}/rules/"*.md             "${TARGET}/rules/"
cp -v "${SOURCE}/scripts/"*              "${TARGET}/scripts/"
cp -v "${SOURCE}/hooks/"*.sh             "${TARGET}/hooks/"
cp -v "${SOURCE}/skills/decompose/"*.md  "${TARGET}/skills/decompose/"
chmod +x "${TARGET}/scripts/"*.py "${TARGET}/scripts/"*.sh "${TARGET}/hooks/"*.sh

echo
echo "Building recall index (this may take ~1 minute on a busy workstation)..."
python3 "${TARGET}/scripts/build_recall_index.py" || echo "(skipped — see error above)"

echo
echo "Done. Suggested cron entries:"
echo
cat <<'EOF'
  */15 * * * * /usr/bin/python3 $HOME/.claude/scripts/build_recall_index.py >/dev/null 2>&1
  55  5 * * * /usr/bin/python3 $HOME/.claude/scripts/doctor_cron.py >/tmp/doctor.log 2>&1
  30  6 * * * $HOME/.claude/scripts/key-monitor.sh >/dev/null 2>&1
  0   * * * * $HOME/.claude/scripts/uptime-check.sh >/dev/null 2>&1
EOF

echo
echo "Add them with:  crontab -e"
echo
echo "Configure ~/.claude/secrets/.env per README. Healthy /doctor runs are silent;"
echo "you'll only get a Telegram message when something fails."
echo
echo "To enable the Definition-of-Done gate, wire hooks/completion-gate.sh into"
echo "~/.claude/settings.json as a PreToolUse hook on your messaging tool —"
echo "see the header of that script for the snippet and GATE_* env knobs."
