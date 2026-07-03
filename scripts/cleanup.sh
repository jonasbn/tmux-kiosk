#!/usr/bin/env bash
SESSION_ID="$1"
PID_FILE="/tmp/tmux-kiosk-${SESSION_ID}.pid"

[ -f "$PID_FILE" ] || exit 0

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
fi
rm -f "$PID_FILE"
