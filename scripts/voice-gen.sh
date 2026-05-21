#!/bin/bash
# voice-gen — generates Czech TTS via Microsoft edge-tts with a leading pause.
#
# Usage:
#   voice-gen.sh <text> <output-path>
#   voice-gen.sh - <output-path>     # text from stdin
#
# Adds 1500ms of silence at the start so the first word doesn't sound rushed.
# Output is .ogg (Telegram-voice compatible).
#
# Requires:
#   edge-tts (pip install edge-tts)
#   ffmpeg

set -euo pipefail

TEXT="${1:?usage: voice-gen.sh <text|-> <output>}"
OUT="${2:?usage: voice-gen.sh <text|-> <output>}"

if [ "$TEXT" = "-" ]; then
  TEXT=$(cat)
fi

VOICE="${VOICE:-cs-CZ-AntoninNeural}"
LEAD_MS="${LEAD_MS:-1500}"

TMP_RAW=$(mktemp --suffix=.mp3)
trap "rm -f $TMP_RAW" EXIT

edge-tts --voice "$VOICE" --text "$TEXT" --write-media "$TMP_RAW" 2>/dev/null
ffmpeg -y -loglevel error -i "$TMP_RAW" -af "adelay=${LEAD_MS}|${LEAD_MS}" -c:a libopus -b:a 48k "$OUT" 2>&1 | tail -3

if [ -f "$OUT" ] && [ -s "$OUT" ]; then
  echo "OK: $OUT ($(du -h "$OUT" | cut -f1))"
else
  echo "FAIL" >&2
  exit 1
fi
