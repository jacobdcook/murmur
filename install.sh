#!/bin/bash
# Install Murmur into the standard locations.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.claude/hooks" "$HOME/.config/murmur"

install -m 0755 "$HERE/bin/murmurd"            "$HOME/.local/bin/murmurd"
install -m 0755 "$HERE/bin/murmur"             "$HOME/.local/bin/murmur"
install -m 0755 "$HERE/bin/murmur-tray"        "$HOME/.local/bin/murmur-tray"
install -m 0755 "$HERE/bin/murmur-bar"         "$HOME/.local/bin/murmur-bar"
install -m 0755 "$HERE/bin/murmur-hold"        "$HOME/.local/bin/murmur-hold"
install -m 0644 "$HERE/hooks/murmur-speak.py"  "$HOME/.claude/hooks/murmur-speak.py"

[ -f "$HOME/.config/murmur/config.json" ] || \
  printf '{\n  "voice": "am_michael",\n  "speed": 1.10,\n  "duck": 25\n}\n' \
    > "$HOME/.config/murmur/config.json"

echo "Installed murmurd, murmur, murmur-tray, murmur-bar, and the Claude hook."
echo
echo "Next:"
echo "  1. Add the Stop hook to ~/.claude/settings.json (see FLOW.md)."
echo "  2. murmur on           # start the daemon"
echo "  3. murmur tray         # taskbar icon"
echo "  4. murmur hotkey-install   # hold Ctrl+I = pause/resume"
echo "  5. murmur voices       # audition voices, then: murmur voice <name>"
echo
echo "Autostart (optional): copy autostart/*.desktop into ~/.config/autostart/"
