# tmux-kiosk: Design Spec

**Date:** 2026-07-03
**Status:** Approved

## Overview

A TPM-compatible tmux plugin that automatically cycles through all windows in a session on a configurable timer interval. When the last window is reached, it wraps back to the first. Designed for dashboard and monitoring use cases where windows display logs, metrics, or status panels hands-free.

## Goals

- Cycle through tmux windows automatically on a timer (kiosk/dashboard mode)
- Toggle on/off via a keybinding without leaving tmux
- Show a status bar indicator when cycling is active
- Scoped per session — each session manages its own independent switcher state
- Clean up background processes automatically when a session closes
- No external dependencies — pure bash and tmux commands only

## Non-Goals

- Global (cross-session) switching
- Idle/screensaver triggered activation
- Runtime interval adjustment (change interval by toggling off and back on)

## File Structure

```
tmux-kiosk/
├── tmux-kiosk.tmux        # TPM entry point
├── scripts/
│   ├── toggle.sh          # start or stop the switcher for a session
│   ├── switcher.sh        # background loop that advances windows
│   └── cleanup.sh         # kills the switcher when a session closes
└── README.md
```

## Configuration

Users set options in `tmux.conf` before the `run` call that loads TPM:

| Option | Default | Description |
|---|---|---|
| `@kiosk-interval` | `10` | Seconds between window switches |
| `@kiosk-key` | `W` | Prefix key to toggle (`prefix + W`) |
| `@kiosk-status` | `⟳` | Indicator text shown in status bar when active |

Example:
```tmux
set -g @plugin 'jonasbn/tmux-kiosk'
set -g @kiosk-interval '15'
set -g @kiosk-key 'W'
```

### Status Bar Integration

The plugin sets the tmux user option `@kiosk-status-active` to the indicator string when running, and clears it to an empty string when stopped. Users include the placeholder in their status line:

```tmux
set -g status-right "#{@kiosk-status-active} | %H:%M"
```

This is non-invasive — the plugin never overwrites the user's full `status-right` or `status-left` string.

## Component Details

### `tmux-kiosk.tmux` (TPM entry point)

Called by TPM on install and reload. Responsibilities:

1. Read user options with fallback to defaults using `tmux show-option -gv`
2. Register the toggle keybinding: `tmux bind-key "$key" run-shell ".../toggle.sh #{session_id}"`
3. Register the session-closed lifecycle hook: `tmux set-hook -g session-closed "run-shell '.../cleanup.sh #{session_id}'"`
4. Store the configured interval as a tmux option so `toggle.sh` can read it at runtime

All script paths are resolved from `CURRENT_DIR` (standard TPM pattern):
```bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### `scripts/switcher.sh`

Signature: `switcher.sh <session_id> <interval>`

Runs as a detached background process. Loop:
```
while true; do
    sleep <interval>
    tmux next-window -t <session_id> || exit 0
done
```

`next-window` natively wraps from last window to first — no special handling needed. If the session no longer exists, `next-window` returns non-zero and the loop exits cleanly.

### `scripts/toggle.sh`

Signature: `toggle.sh <session_id>`

PID file path: `/tmp/tmux-kiosk-<session_id>.pid`

Logic:
1. If PID file exists and `kill -0 <pid>` succeeds (process is alive):
   - Kill the process
   - Remove the PID file
   - Clear `@kiosk-status-active` on the session
2. Otherwise:
   - Read `@kiosk-interval` (with default fallback)
   - Read `@kiosk-status` (with default fallback)
   - Spawn `switcher.sh <session_id> <interval>` in background
   - Write its PID to the PID file
   - Set `@kiosk-status-active` to the indicator string on the session

### `scripts/cleanup.sh`

Signature: `cleanup.sh <session_id>`

Idempotent — safe to call even if the switcher is already stopped.

1. Check for `/tmp/tmux-kiosk-<session_id>.pid`
2. If found, kill the process (if alive) and remove the PID file
3. No need to clear the status option — the session is closing

## Lifecycle & Edge Cases

| Scenario | Behaviour |
|---|---|
| Session closed while switcher is active | `session-closed` hook calls `cleanup.sh`, kills background process |
| Toggled off manually before session closes | PID file removed; hook runs but is a no-op |
| tmux server killed | OS reaps all child processes naturally |
| Interval changed in config | Requires toggle off + on to take effect; interval is read once at start |
| Single window in session | `next-window` is a no-op — plugin runs harmlessly |

## Installation

Via TPM — add to `tmux.conf`:
```tmux
set -g @plugin 'jonasbn/tmux-kiosk'
```
Then `prefix + I` to install.

Manual install:
```bash
git clone https://github.com/jonasbn/tmux-kiosk \
  ~/.config/tmux/plugins/tmux-kiosk
~/.config/tmux/plugins/tmux-kiosk/tmux-kiosk.tmux
```
