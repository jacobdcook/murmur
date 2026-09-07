# jarvis-voice — end-to-end flow

## The loop

```
                    YOU
                     |
   hold `  (GRAVE)   |   hear reply
        v            |        ^
   +---------+       |   +----------+
   | voxflow |       |   | jarvisd  |  Kokoro TTS daemon (GPU)
   | Whisper |       |   | am_michael, 1.10x
   +----+----+       |   +----+-----+
        |            |        ^  plays on default audio sink
        | types text |        |
        | into prompt|        | UTF-8 text over unix socket
        v            |        |  /tmp/jarvis.sock
   +---------------------------+---+
   |        Claude Code            |
   |  turn ends -> Stop hook fires |
   |  jarvis-speak.py              |
   +-------------------------------+
```

## Input side (already installed, not part of this repo)

- `voxflow` autostarts at login (`~/.config/autostart/voxflow.desktop`).
- Hold **`** (GRAVE, keycode 49) to dictate; release to insert text.
- Config: `~/.config/mintflow/config.json` — Whisper `large-v3`, `device: cuda`,
  ollama `qwen2.5:14b` cleanup pass, hotkey `keycode:49`.
- This repo does not touch voxflow. It only adds the spoken-output half.

## Output side (this repo)

### 1. `jarvisd` — the daemon (`bin/jarvisd`)

- On start: loads Kokoro `KPipeline(lang_code='a')` once (~10-20s, prints
  `jarvisd: ready` to `~/.cache/jarvisd.log`).
- Binds unix socket `/tmp/jarvis.sock` (mode 0600).
- A background player thread pulls text off a queue, synthesizes with
  `voice=am_michael, speed=1.10`, plays via `sounddevice` on the default sink.
- Socket protocol: connect, send UTF-8 text, close. Text is queued and spoken.
- Special payload `__STOP__`: drains the queue and calls `sd.stop()` (this is
  what `jarvis hush` sends).
- Env overrides read at start: `JARVIS_VOICE`, `JARVIS_SPEED`.
- Text is capped at 3000 chars per message.

### 2. `jarvis` — the control CLI (`bin/jarvis`)

| Command | Action |
| --- | --- |
| `jarvis on` | `nohup jarvisd` if not already running; logs to `~/.cache/jarvisd.log` |
| `jarvis off` | `pkill -f '/jarvisd$'` |
| `jarvis say TEXT` | opens socket, sends TEXT |
| `jarvis hush` | sends `__STOP__` |
| `jarvis status` | `running` / `stopped` |

"Voice on/off" == "daemon up/down". When the daemon is down, the Stop hook's
socket connect fails and it silently no-ops — so leaving the hook installed costs
nothing when you don't want voice.

### 3. `jarvis-speak.py` — the Claude Code Stop hook (`hooks/jarvis-speak.py`)

Fires when a Claude turn ends. Claude Code passes the hook a JSON blob on stdin
containing `transcript_path`. The hook:

1. Reads the transcript JSONL, walks it, keeps the **last** `assistant` entry that
   has a non-empty text block (so tool-only turns and earlier messages are
   skipped — only the final spoken reply plays).
2. Cleans the markdown for speech: strips code fences (replaced with the phrase
   "Code block."), headings, link URLs, table rows, `**`, backticks, list
   bullets; collapses whitespace.
3. Caps at 3000 chars, opens `/tmp/jarvis.sock`, sends the text, closes.
4. Any error (daemon down, no transcript, parse fail) -> silent return. Never
   blocks or errors the turn.

## Wiring the hook into Claude Code

Add to `~/.claude/settings.json` under `hooks`:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "python3 \"/home/z1337/.claude/hooks/jarvis-speak.py\"",
        "timeout": 5,
        "async": true,
        "statusMessage": "Jarvis speaking..."
      }
    ]
  }
]
```

`async: true` so synthesis never blocks the next prompt. After editing settings
mid-session, open `/hooks` once or restart Claude Code so the watcher reloads.

## Daily use

```bash
jarvis on          # after boot, when you want voice
# ... work in Claude Code; every reply is spoken ...
jarvis hush        # shut it up mid-sentence
jarvis off         # done for the day
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No audio at all | `jarvis status` (is it running?), then `jarvis say test` |
| Daemon "running" but silent | `pactl get-default-sink` — Kokoro plays to the default sink; switch sink or restart daemon after changing it |
| Hook not firing this session | settings changed mid-session — open `/hooks` once or restart Claude Code |
| Model won't load | `tail ~/.cache/jarvisd.log`; confirm `python3 -c "import kokoro, sounddevice, soundfile, numpy"` for your user |
| Wrong voice/speed | `JARVIS_VOICE=af_heart JARVIS_SPEED=1.0 jarvis on` |

## Design decisions

- **No autostart.** Deliberate — a prior autostart script on this machine caused a
  hardware incident, so voice is opt-in per boot.
- **Daemon, not per-call TTS.** Kokoro's model load is the expensive part; loading
  once and holding it in a resident process makes each reply near-instant.
- **Unix socket, 0600.** Local-only, user-only; no network surface.
- **Fail-silent hook.** The hook must never break a Claude turn, so every failure
  path returns quietly.
