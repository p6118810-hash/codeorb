#!/usr/bin/env python3
"""
CodeOrb Codex hook bridge.

- Reads Codex hook payloads from stdin
- Enriches them with local process metadata
- Sends session state to the macOS app over a Unix socket
"""

import json
import os
import socket
import subprocess
import sys

SOCKET_PATH = "/tmp/codeorb.sock"
TIMEOUT_SECONDS = 5


def get_tty():
    """Get the TTY for the parent Codex process when available."""
    ppid = os.getppid()

    try:
        result = subprocess.run(
            ["ps", "-p", str(ppid), "-o", "tty="],
            capture_output=True,
            text=True,
            timeout=2,
        )
        tty = result.stdout.strip()
        if tty and tty not in {"??", "-"}:
            return tty if tty.startswith("/dev/") else "/dev/" + tty
    except Exception:
        pass

    for stream in (sys.stdin, sys.stdout, sys.stderr):
        try:
            return os.ttyname(stream.fileno())
        except (OSError, AttributeError):
            continue

    return None


def send_event(state):
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT_SECONDS)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(state).encode())
        sock.close()
    except (socket.error, OSError):
        pass


def map_status(event_name):
    if event_name == "UserPromptSubmit":
        return "processing"
    if event_name == "Stop":
        return "waiting_for_input"
    if event_name == "SessionStart":
        return "waiting_for_input"
    return "unknown"


def main():
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(1)

    event_name = payload.get("hook_event_name", "")
    state = {
        "session_id": payload.get("session_id", "unknown"),
        "cwd": payload.get("cwd", ""),
        "event": event_name,
        "status": map_status(event_name),
        "pid": os.getppid(),
        "tty": get_tty(),
        "transcript_path": payload.get("transcript_path"),
        "prompt": payload.get("prompt"),
        "last_assistant_message": payload.get("last_assistant_message"),
    }

    send_event(state)


if __name__ == "__main__":
    main()
