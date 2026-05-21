#!/bin/bash
# transcribe — Groq Whisper API speech-to-text.
#
# Usage: transcribe.sh <audio-file>
# Returns transcription text on stdout.
#
# WHY: an inline `python3 <<'EOF' ... whisper ... EOF` triggers Claude Code
# "complex Bash" permission gates even with --dangerously-skip-permissions.
# A plain shell script call is whitelistable and 10x faster (Groq cloud GPU
# vs local CPU faster_whisper).
#
# Requires:
#   GROQ_API_KEY in ~/.claude/secrets/.env (KEY=VALUE format).
#   Default language is Czech (cs); override via LANG_CODE env var.

set -euo pipefail

INPUT="${1:-}"
if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
    echo "Usage: $0 <audio-file>" >&2
    exit 2
fi

SECRETS="${SECRETS:-$HOME/.claude/secrets/.env}"
GROQ_API_KEY=$(grep '^GROQ_API_KEY=' "$SECRETS" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
if [ -z "${GROQ_API_KEY}" ]; then
    echo "GROQ_API_KEY missing in $SECRETS" >&2
    exit 3
fi

# Groq accepts: flac mp3 mp4 mpeg mpga m4a ogg opus wav webm (NOT .oga).
# Telegram voice arrives as .oga but is actually Opus-in-OGG → rename hint.
EXT="${INPUT##*.}"
if [ "$EXT" = "oga" ]; then
    UPLOAD_NAME="$(basename "${INPUT%.oga}").ogg"
else
    UPLOAD_NAME="$(basename "${INPUT}")"
fi

LANG_CODE="${LANG_CODE:-cs}"

curl -sS -f https://api.groq.com/openai/v1/audio/transcriptions \
    -H "Authorization: Bearer ${GROQ_API_KEY}" \
    -F "file=@${INPUT};filename=${UPLOAD_NAME}" \
    -F "model=whisper-large-v3-turbo" \
    -F "language=${LANG_CODE}" \
    -F "response_format=text"
