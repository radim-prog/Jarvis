#!/usr/bin/env bash
# install.sh — copy Jarvis files into ~/.claude/, build recall index, suggest cron
set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}/.claude"

echo "Installing Jarvis from ${SOURCE} into ${TARGET}"

mkdir -p "${TARGET}/commands" "${TARGET}/rules" "${TARGET}/scripts"

cp -v "${SOURCE}/commands/"*.md "${TARGET}/commands/"
cp -v "${SOURCE}/rules/"*.md     "${TARGET}/rules/"
cp -v "${SOURCE}/scripts/"*       "${TARGET}/scripts/"
chmod +x "${TARGET}/scripts/"*.py "${TARGET}/scripts/"*.sh

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
