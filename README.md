# tmux-kiosk

A tmux plugin for hands-free window monitoring and cycling. Perfect for dashboard monitoring, status displays, and other scenarios where you want windows to rotate automatically at a fixed interval. tmux-kiosk lets you enable or disable auto-cycling with a single keybinding, with optional visual feedback in the status bar.

![tmux-kiosk demo: three windows (dashboard, logs, metrics) auto-cycling every few seconds, with the status bar indicator turning on and off via prefix+W](docs/demo.gif)

## Features

- Toggle auto-switching on/off with a single keybinding
- Configurable interval between window switches
- Optional status bar indicator shows when kiosk mode is active
- Session-scoped: each session manages its own state independently
- Automatic cleanup when a session closes
- No external dependencies — pure bash and tmux

## Requirements

- tmux ≥ 2.1
- bash ≥ 3.2
- TPM (optional, for managed install)

## Installation

### Via TPM

Add this line to your `~/.tmux.conf`:

```
set -g @plugin 'jonasbn/tmux-kiosk'
```

Then press `prefix + I` to install the plugin.

### Manual

Clone the repository directly:

```bash
git clone https://github.com/jonasbn/tmux-kiosk \
  ~/.config/tmux/plugins/tmux-kiosk
~/.config/tmux/plugins/tmux-kiosk/tmux-kiosk.tmux
```

## Configuration

| Option            | Default | Description                        |
|-------------------|---------|------------------------------------|
| `@kiosk-interval` | `10`    | Seconds between window switches    |
| `@kiosk-key`      | `W`     | Toggle key (used with tmux prefix) |
| `@kiosk-status`   | `⟳`     | Status bar text shown when active  |

Add these to your `~/.tmux.conf` to customize:

```
set -g @kiosk-interval 15
set -g @kiosk-key W
set -g @kiosk-status "⟳"
```

## Status Bar Integration

Use the `#{@kiosk-status-active}` placeholder in your `status-right` or `status-left` to show when kiosk mode is active:

```
set -g status-right "#{@kiosk-status-active} | %H:%M"
```

When kiosk mode is on, this will display the configured status symbol (default `⟳`). When off, it displays nothing.

## Usage

- Press `prefix + W` to start auto-switching (default: Windows/Dashboard key)
- Press `prefix + W` again to stop auto-switching
- Changing `@kiosk-interval` takes effect on the next toggle-on

## Notes

- Window switching automatically wraps from the last window to the first
- Sessions with a single window run harmlessly without error
- The background switching process is cleaned up automatically when the session closes or exits tmux

## Motivation

I often have quite a few terminal windows open, where I monitor various things.

- `codeburn`
- `abtop`
- `wtfutil`

Since I am not watching these constantly but they take up a lot of Desktop space, I needed something for rotating them in a single terminal.

So using Claude code I developed this and I was actually working on something else, so I let Claude do the coding.

## License

MIT
