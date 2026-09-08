#!/usr/bin/env python3
"""Claude Code Stop hook: send the last assistant message to the murmurd
Kokoro TTS daemon. Fails silently if the daemon is not running, so
`murmur on` / `murmur off` is the voice toggle."""
import json
import re
import socket
import sys

SOCK = "/tmp/murmur.sock"
MAX_CHARS = 6000


def clean(text):
    text = re.sub(r"```.*?```", " Code block. ", text, flags=re.S)
    text = re.sub(r"^\s{0,3}#{1,6}\s+", "", text, flags=re.M)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"^\|.*\|\s*$", "", text, flags=re.M)
    text = text.replace("**", "").replace("`", "")
    text = re.sub(r"^\s*[-*]\s+", "", text, flags=re.M)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{2,}", "\n", text)
    return text.strip()


def main():
    try:
        payload = json.load(sys.stdin)
        path = payload.get("transcript_path")
        if not path:
            return
        last = None
        with open(path) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if entry.get("type") != "assistant":
                    continue
                content = entry.get("message", {}).get("content", [])
                texts = [
                    b.get("text", "")
                    for b in content
                    if isinstance(b, dict) and b.get("type") == "text"
                ]
                if any(t.strip() for t in texts):
                    last = "\n".join(t for t in texts if t.strip())
        if not last:
            return
        text = clean(last)[:MAX_CHARS]
        if not text:
            return
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1)
        s.connect(SOCK)
        s.sendall(text.encode())
        s.close()
    except Exception:
        pass


if __name__ == "__main__":
    main()
