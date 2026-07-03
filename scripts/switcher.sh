#!/usr/bin/env bash
SESSION_ID="$1"
INTERVAL="$2"

while true; do
    sleep "$INTERVAL"
    tmux next-window -t "$SESSION_ID" 2>/dev/null || exit 0
done
