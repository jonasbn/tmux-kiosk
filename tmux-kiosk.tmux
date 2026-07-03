#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INTERVAL=$(tmux show-option -gv @kiosk-interval 2>/dev/null)
INTERVAL="${INTERVAL:-10}"

KEY=$(tmux show-option -gv @kiosk-key 2>/dev/null)
KEY="${KEY:-W}"

tmux set-option -g @kiosk-interval "$INTERVAL"

tmux bind-key "$KEY" run-shell \
    "$CURRENT_DIR/scripts/toggle.sh '#{session_id}'"

tmux set-hook -ag session-closed \
    "run-shell '$CURRENT_DIR/scripts/cleanup.sh #{session_id}'"
