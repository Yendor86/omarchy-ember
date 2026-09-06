#!/usr/bin/env bash
# One-time setup for ember-voice: local Whisper (STT) + Piper (TTS) in a venv.
# No sudo, no API key — the brain is your logged-in `claude` CLI.
set -euo pipefail
DATA="$HOME/.local/share/ember-voice"; VOICES="$DATA/voices"
VOICE="${EMBER_VOICE:-en_US-amy-medium}"
mkdir -p "$VOICES"
echo "Creating Python venv at $DATA/venv…"
python3 -m venv "$DATA/venv"
"$DATA/venv/bin/pip" install --quiet --upgrade pip
echo "Installing faster-whisper + piper-tts (a few hundred MB, one time)…"
"$DATA/venv/bin/pip" install --quiet faster-whisper piper-tts
if [ ! -f "$VOICES/$VOICE.onnx" ]; then
  echo "Downloading voice: $VOICE…"
  lang="${VOICE%%-*}"; rest="${VOICE#*-}"; name="${rest%-*}"; qual="${rest##*-}"
  base="https://huggingface.co/rhasspy/piper-voices/resolve/main/${lang%_*}/${lang}/${name}/${qual}"
  curl -fsSL "$base/$VOICE.onnx"      -o "$VOICES/$VOICE.onnx"
  curl -fsSL "$base/$VOICE.onnx.json" -o "$VOICES/$VOICE.onnx.json"
fi
echo "Warming up the speech model…"
"$DATA/venv/bin/python" -c "from faster_whisper import WhisperModel; WhisperModel('base.en', device='cpu', compute_type='int8')"
echo "Done. Start talking with:  ember-voice"
