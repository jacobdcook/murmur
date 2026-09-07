# jarvis-voice

Local, GPU-backed voice loop for Claude Code (and any CLI). Talk in by holding a
key; hear Claude's replies spoken back through a Kokoro TTS daemon running on the
GPU. No cloud TTS, no per-word latency after the model is warm.

- **Input** (already on this machine): `voxflow` — hold **`** (backtick / GRAVE)
  to dictate. Whisper `large-v3` on CUDA, cleaned up by a local ollama model.
- **Output** (this repo): `jarvisd`, a Kokoro TTS daemon that loads the model
  once and speaks any text sent to its unix socket. A Claude Code **Stop hook**
  feeds it Claude's last message after every turn.

Toggle the whole thing with `jarvis on` / `jarvis off`. Daemon running = voice on.

See [FLOW.md](FLOW.md) for the end-to-end data flow and troubleshooting.

## Layout

| Path | Installs to | What it is |
| --- | --- | --- |
| `bin/jarvisd` | `~/.local/bin/jarvisd` | Kokoro daemon; unix socket `/tmp/jarvis.sock` |
| `bin/jarvis` | `~/.local/bin/jarvis` | Control CLI: `on\|off\|say\|hush\|status` |
| `hooks/jarvis-speak.py` | `~/.claude/hooks/jarvis-speak.py` | Claude Code Stop hook |

## Install

```bash
git clone git@github.com:jacobdcook/jarvis-voice.git
cd jarvis-voice
./install.sh
```

Then register the Stop hook in `~/.claude/settings.json` (see FLOW.md), start the
daemon, and go:

```bash
jarvis on
```

## Requirements

- Python 3.12 with `kokoro`, `sounddevice`, `soundfile`, `numpy` installed for the
  user (not a venv — the daemon runs as your login user so audio reaches the
  default sink).
- A working audio output (PulseAudio / PipeWire). Check `pactl get-default-sink`.
- GPU optional but intended; Kokoro will use it if present.

## Commands

```
jarvis on        # start daemon (idempotent)
jarvis off       # kill daemon — voice off, hook no-ops
jarvis say TEXT  # speak arbitrary text
jarvis hush      # cut current playback + clear queue
jarvis status    # running | stopped
```

## Notes

- **Not autostarted on purpose.** Run `jarvis on` after boot when you want voice.
- Env overrides: `JARVIS_VOICE` (default `am_michael`), `JARVIS_SPEED` (default `1.10`).
- Daemon log: `~/.cache/jarvisd.log`.
