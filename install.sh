#!/usr/bin/env bash
# Install Ember as an Omarchy shell plugin (symlinks this repo so edits
# hot-reload), puts the `ember` CLI on your PATH, enables it, reloads the shell.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
PLUGID="yendor.ember"
DEST="$HOME/.config/omarchy/plugins/$PLUGID"

ln -sfn "$SRC" "$DEST"
echo "linked $DEST -> $SRC"

mkdir -p "$HOME/.local/bin"
ln -sfn "$SRC/bin/ember" "$HOME/.local/bin/ember"
ln -sfn "$SRC/bin/ember-audio" "$HOME/.local/bin/ember-audio"
ln -sfn "$SRC/bin/ember-voice" "$HOME/.local/bin/ember-voice"
echo "linked ember + ember-audio + ember-voice CLIs -> ~/.local/bin/"

mkdir -p "${XDG_RUNTIME_DIR:-/tmp}/ember"
printf 'idle\n' > "${XDG_RUNTIME_DIR:-/tmp}/ember/state"

omarchy plugin enable "$PLUGID" 2>/dev/null || true
omarchy restart shell 2>/dev/null || omarchy refresh shell 2>/dev/null || true

echo
echo "Ember is installed. It's glowing in the bottom-right corner."
echo "Talk to it:   ember thinking   |   ember speaking   |   ember alert   |   ember idle"
echo "(if ~/.local/bin isn't on PATH, add it — Omarchy usually has it already)"
