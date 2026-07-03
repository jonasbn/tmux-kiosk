#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_ID="$1"
PID_FILE="/tmp/tmux-kiosk-${SESSION_ID}.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm -f "$PID_FILE"
        tmux set-option -t "$SESSION_ID" @kiosk-status-active "" 2>/dev/null
        exit 0
    fi
    rm -f "$PID_FILE"
fi

INTERVAL=$(tmux show-option -gv @kiosk-interval 2>/dev/null)
INTERVAL="${INTERVAL:-10}"

STATUS_TEXT=$(tmux show-option -gv @kiosk-status 2>/dev/null)
STATUS_TEXT="${STATUS_TEXT:-⟳}"

"$CURRENT_DIR/scripts/switcher.sh" "$SESSION_ID" "$INTERVAL" > /dev/null 2>&1 &
echo $! > "$PID_FILE"

tmux set-option -t "$SESSION_ID" @kiosk-status-active "$STATUS_TEXT" 2>/dev/null
