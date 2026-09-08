# Murmur

Local, GPU-backed voice for [Claude Code](https://claude.com/claude-code) (and any
CLI). Hear Claude's replies spoken aloud by a resident [Kokoro](https://github.com/hexgrad/kokoro)
TTS daemon — it **murmurs under your music** (ducks other audio while it talks),
starts speaking in about a second even on long replies, and gives you a taskbar
icon plus a global hotkey to pause, resume, and skip. No cloud TTS.

Pair it with any push-to-talk dictation tool (the author uses
[voxflow](https://github.com/jacobdcook)/Whisper on a hotkey) and you have a full
spoken conversation loop with your terminal.

![state: idle | speaking | paused](https://img.shields.io/badge/tray-idle%20%7C%20speaking%20%7C%20paused-blue)

## What you get

- **Streaming playback** — speaks each sentence as it's synthesized, so the first
  words start in ~1s instead of after the whole reply is rendered.
- **Music ducking** — lowers every other PulseAudio/PipeWire stream to 25% while
  speaking, restores it when done.
- **Real pause / resume** — not just stop. Hold a thought, reply, resume.
- **Hold-to-pause hotkey** — hold `Ctrl+I` to pause, release to resume
  (momentary, like a push-to-talk key). A low/high beep confirms pause/resume so
  you don't need to look.
- **Taskbar tray icon** — live state + a menu for pause/skip/voice switching,
  like a media applet. (An always-on-top mini bar is included as an alternative.)
- **Voice auditioning** — `murmur voices` speaks a sample line in each candidate
  voice so you can pick, then `murmur voice <name>` sets it.

## Install

```bash
git clone https://github.com/jacobdcook/murmur.git
cd murmur
./install.sh
```

Requirements: Python 3.12 with `kokoro`, `sounddevice`, `soundfile`, `numpy`
installed **for your user** (not a venv — the daemon plays to your default audio
device). For the tray/bar: `python3-gi` with GTK 3, and `gir1.2-appindicator3`
(or Ayatana). `pactl` is used for ducking.

## Wire it into Claude Code

Add a **Stop hook** to `~/.claude/settings.json` so every finished reply is spoken
(see [FLOW.md](FLOW.md) for the exact JSON). The hook fails silently when the
daemon is off, so it costs nothing when you don't want voice.

## Use

```bash
murmur on              # start the daemon (voice on)
murmur tray            # taskbar icon
murmur hotkey-install  # hold Ctrl+I = pause/resume
murmur bar             # visible always-on-top control strip (top-left)

murmur voices          # audition voices out loud
murmur voice am_adam   # set the voice
murmur speed 1.15      # set the pace
murmur duck 20         # music volume % while speaking

murmur pause | resume | toggle | skip | status
murmur off             # voice off
```

Not autostarted by default. Run `murmur on` after boot. To start automatically,
copy `autostart/murmur-tray.desktop` into `~/.config/autostart/` and add a second
entry (or a line) that runs `murmur on` — the tray controls the daemon but does
not launch it for you.

See [FLOW.md](FLOW.md) for architecture, the socket protocol, and troubleshooting.

## License

MIT.
