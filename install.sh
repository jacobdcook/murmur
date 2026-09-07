#!/bin/bash
# Install jarvis-voice into the standard locations.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.claude/hooks"

install -m 0755 "$HERE/bin/jarvisd"            "$HOME/.local/bin/jarvisd"
install -m 0755 "$HERE/bin/jarvis"             "$HOME/.local/bin/jarvis"
install -m 0644 "$HERE/hooks/jarvis-speak.py"  "$HOME/.claude/hooks/jarvis-speak.py"

echo "Installed:"
echo "  ~/.local/bin/jarvisd"
echo "  ~/.local/bin/jarvis"
echo "  ~/.claude/hooks/jarvis-speak.py"
echo
echo "Next: add the Stop hook to ~/.claude/settings.json (see FLOW.md), then:"
echo "  jarvis on"
