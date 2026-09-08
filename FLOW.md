# Murmur — end-to-end flow

## The loop

```
                         YOU
                          |
   push-to-talk (Whisper) |   hear reply (ducked over music)
        v                 |            ^
   +-----------+          |     +--------------+
   | dictation |          |     |   murmurd    |  Kokoro TTS daemon (GPU)
   | -> text   |          |     |  streaming   |  speaks sentence-by-sentence
   +-----+-----+          |     +------+-------+
         | types into     |            ^  plays on default sink; ducks others
         | the prompt     |            |
         v                |            |  UTF-8 / control over unix socket
   +---------------------------+-------+---+       /tmp/murmur.sock
   |          Claude Code                  |          ^        ^
   |  turn ends -> Stop hook fires         |          |        |
   |  murmur-speak.py -> socket            |     murmur-tray  Ctrl+Alt+Space
   +---------------------------------------+     (taskbar)    -> murmur toggle
```

## Components

### `murmurd` — the daemon (`bin/murmurd`)

- Loads Kokoro `KPipeline` once (~15-20s; logs `murmurd: ready` to
  `~/.cache/murmurd.log`).
- Binds `/tmp/murmur.sock` (0600, user-only).
- **Streaming**: iterates the segments Kokoro yields for the text and plays each
  the moment it's synthesized, so first audio is ~1s even for long replies.
- **Playback** uses a callback-driven `sounddevice.OutputStream`, which is what
  makes real pause/resume possible (the callback emits silence while paused and
  resumes from the same position — the stream is never torn down).
- **Ducking**: on speech start it lowers every *other* PulseAudio sink-input
  (matched by process id, so it never ducks itself) to `duck`% and restores the
  saved levels once the queue drains.
- **Config**: re-reads `~/.config/murmur/config.json` before each utterance, so
  `voice` / `speed` / `duck` changes take effect on the next line without a
  restart. Env `MURMUR_*` is not needed — everything is in the config file.

### `murmur` — the CLI (`bin/murmur`)

| Command | Action |
| --- | --- |
| `on` / `off` | start / stop the daemon |
| `say <text>` | speak text |
| `pause` / `resume` / `toggle` | pause control (hotkey + tray use `toggle`) |
| `skip` (aka `hush`/`stop`) | abandon current utterance + clear the queue |
| `status` | JSON: `{state, queued, text}` |
| `voice <name>` / `speed <x>` / `duck <pct>` | persist a config value |
| `voices [line]` | speak a sample line in each candidate voice |
| `tray` / `bar` | launch the taskbar icon / the floating mini bar |
| `hotkey-install` | bind `Ctrl+Alt+Space` -> `murmur toggle` (Cinnamon) |

Voice on/off == daemon up/down. With the daemon down, the Stop hook's socket
connect fails and it no-ops.

### `murmur-tray` — taskbar icon (`bin/murmur-tray`)

AppIndicator (Cinnamon/GNOME tray). Label shows live state (`▮▮ speaking`,
`▶ paused`, `· idle`, `○ off`). Menu: Pause/Resume, Skip, a **Voice** submenu that
switches voice live, and Quit. Polls `__STATUS__` every 0.7s.

### `murmur-bar` — floating mini bar (`bin/murmur-bar`)

Alternative to the tray: a small always-on-top, top-left GTK strip with a
pause/resume button, a skip button, a state dot, and the current-text readout.
Use it if you'd rather have a visible widget than a tray icon.

### `murmur-speak.py` — the Claude Code Stop hook (`hooks/murmur-speak.py`)

Fires when a turn ends. Reads `transcript_path` from the hook's stdin JSON, takes
the **last** assistant text block, strips markdown/code fences for speech, caps at
6000 chars, and sends it to the socket. Any failure -> silent return (never blocks
a turn).

## Socket protocol

Connect to `/tmp/murmur.sock`, send UTF-8, close:

| Payload | Meaning |
| --- | --- |
| plain text | speak with the default voice |
| `#voice=NAME\n<text>` | speak `<text>` with a one-off voice |
| `__PAUSE__` / `__RESUME__` / `__TOGGLE__` | pause control |
| `__STOP__` | skip current + clear queue |
| `__STATUS__` | daemon writes one JSON line back, then closes |

Clients that want the `__STATUS__` reply must `shutdown(SHUT_WR)` after sending so
the daemon sees end-of-input before it replies.

## Wiring the Stop hook

`~/.claude/settings.json`:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "python3 \"/home/YOU/.claude/hooks/murmur-speak.py\"",
        "timeout": 5,
        "async": true,
        "statusMessage": "Murmur speaking..."
      }
    ]
  }
]
```

`async: true` so synthesis never blocks the next prompt. After editing settings
mid-session, open `/hooks` once or restart Claude Code so the watcher reloads.

## Global hotkey

`murmur hotkey-install` registers a Cinnamon custom keybinding
(`Ctrl+Alt+Space` -> `murmur toggle`). On other desktops, bind that command to any
key via your DE's keyboard settings — `murmur toggle` is all it runs.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No audio | `murmur status`; `tail ~/.cache/murmurd.log` for a stack trace |
| `'Tensor' object has no attribute 'astype'` | old build — update; segments are torch tensors and must be converted before playback |
| Speaking but silent | `pactl get-default-sink` — daemon plays to the default sink |
| Music not ducking | confirm `pactl` works and the other app is a normal sink-input |
| Hook not firing this session | settings changed mid-session — open `/hooks` or restart |
| Tray icon missing | need `gir1.2-appindicator3-0.1` (or Ayatana); check `/tmp` tray log |

## Design decisions

- **Daemon, not per-call TTS.** Kokoro's model load is the cost; hold it resident.
- **Callback OutputStream.** Only way to get resumable pause without re-synth.
- **Duck by process id.** Reliable self-exclusion; no fragile name matching.
- **Fail-silent hook.** Must never break a Claude turn.
- **No autostart by default.** Opt-in per machine.
