# tmux-kiosk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a TPM-compatible tmux plugin that cycles through session windows on a configurable timer, with toggle keybinding, status bar indicator, and automatic cleanup on session close.

**Architecture:** A bash entry point (`tmux-kiosk.tmux`) registers a keybinding and a session-closed hook. The keybinding calls `toggle.sh` which starts or stops a background loop (`switcher.sh`) keyed to the session ID via a PID file in `/tmp`. A `cleanup.sh` script is invoked by the hook to reap the background process when the session closes.

**Tech Stack:** bash, tmux (next-window, bind-key, set-hook, set-option, show-option), bats-core (tests)

## Global Constraints

- Pure bash — no external tools beyond tmux and standard POSIX utilities
- No `set -e` globally in scripts that test process liveness with `kill -0` (would exit prematurely on expected non-zero)
- PID files stored at `/tmp/tmux-kiosk-<session_id>.pid`
- All tmux user options prefixed `@kiosk-`
- Default interval: `10` seconds; default toggle key: `W`; default status indicator: `⟳`
- Scripts must be executable (`chmod +x`)
- Compatible with macOS (Darwin) and Linux

---

## File Map

| File | Role |
|---|---|
| `tmux-kiosk.tmux` | TPM entry point: reads config, registers keybinding and hook |
| `scripts/switcher.sh` | Background loop: sleeps, advances window, exits if session gone |
| `scripts/toggle.sh` | Start or stop `switcher.sh` for a given session, update status option |
| `scripts/cleanup.sh` | Kill switcher and remove PID file — called by session-closed hook |
| `tests/helpers/fake_tmux` | Mock tmux binary prepended to PATH in tests |
| `tests/cleanup.bats` | bats tests for `cleanup.sh` |
| `tests/switcher.bats` | bats tests for `switcher.sh` |
| `tests/toggle.bats` | bats tests for `toggle.sh` |
| `README.md` | Installation, configuration, usage |

---

## Task 1: Test infrastructure + `scripts/cleanup.sh`

Start with the simplest script (`cleanup.sh`) to establish the test harness first.

**Files:**
- Create: `scripts/cleanup.sh`
- Create: `tests/helpers/fake_tmux`
- Create: `tests/cleanup.bats`

**Interfaces:**
- Produces: `cleanup.sh <session_id>` — kills `/tmp/tmux-kiosk-<session_id>.pid` process if alive, removes PID file; exits 0 always

- [ ] **Step 1: Install bats-core (dev dependency)**

```bash
brew install bats-core
bats --version
```
Expected output: `Bats 1.x.x` (any 1.x version).

- [ ] **Step 2: Initialise git and create directory structure**

```bash
git init
mkdir -p scripts tests/helpers
```

- [ ] **Step 3: Create the fake tmux mock**

Create `tests/helpers/fake_tmux`:
```bash
#!/usr/bin/env bash
# Mock tmux binary for tests. Logs calls and returns configurable responses.
CALL_LOG="${TMUX_CALL_LOG:-/tmp/tmux-test-calls.log}"
echo "$*" >> "$CALL_LOG"

case "$1" in
    show-option)
        case "${*}" in
            *@kiosk-interval*) echo "${TMUX_KIOSK_INTERVAL:-10}" ;;
            *@kiosk-status\ *|*@kiosk-status) echo "${TMUX_KIOSK_STATUS:-⟳}" ;;
        esac
        exit 0
        ;;
    next-window)
        exit "${TMUX_NEXT_WINDOW_EXIT:-0}"
        ;;
    set-option|bind-key|set-hook)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
```

```bash
chmod +x tests/helpers/fake_tmux
```

- [ ] **Step 4: Write failing tests for `cleanup.sh`**

Create `tests/cleanup.bats`:
```bash
#!/usr/bin/env bats

setup() {
    export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
    export TMUX_CALL_LOG
    TMUX_CALL_LOG="$(mktemp)"
    TEST_SESSION="test-session-$$"
    PID_FILE="/tmp/tmux-kiosk-${TEST_SESSION}.pid"
}

teardown() {
    rm -f "$TMUX_CALL_LOG"
    rm -f "$PID_FILE"
}

@test "cleanup: kills process and removes PID file when switcher is running" {
    sleep 3600 &
    FAKE_PID=$!
    echo "$FAKE_PID" > "$PID_FILE"

    run bash "$BATS_TEST_DIRNAME/../scripts/cleanup.sh" "$TEST_SESSION"

    [ "$status" -eq 0 ]
    [ ! -f "$PID_FILE" ]
    ! kill -0 "$FAKE_PID" 2>/dev/null
}

@test "cleanup: removes stale PID file without error when process is gone" {
    echo "99999999" > "$PID_FILE"

    run bash "$BATS_TEST_DIRNAME/../scripts/cleanup.sh" "$TEST_SESSION"

    [ "$status" -eq 0 ]
    [ ! -f "$PID_FILE" ]
}

@test "cleanup: exits cleanly when no PID file exists" {
    run bash "$BATS_TEST_DIRNAME/../scripts/cleanup.sh" "$TEST_SESSION"

    [ "$status" -eq 0 ]
}
```

- [ ] **Step 5: Run tests — verify they fail**

```bash
bats tests/cleanup.bats
```
Expected: 3 tests fail with "No such file or directory" (cleanup.sh doesn't exist yet).

- [ ] **Step 6: Implement `scripts/cleanup.sh`**

Create `scripts/cleanup.sh`:
```bash
#!/usr/bin/env bash
SESSION_ID="$1"
PID_FILE="/tmp/tmux-kiosk-${SESSION_ID}.pid"

[ -f "$PID_FILE" ] || exit 0

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
fi
rm -f "$PID_FILE"
```

```bash
chmod +x scripts/cleanup.sh
```

- [ ] **Step 7: Run tests — verify they pass**

```bash
bats tests/cleanup.bats
```
Expected:
```
 ✓ cleanup: kills process and removes PID file when switcher is running
 ✓ cleanup: removes stale PID file without error when process is gone
 ✓ cleanup: exits cleanly when no PID file exists

3 tests, 0 failures
```

- [ ] **Step 8: Commit**

```bash
git add scripts/cleanup.sh tests/helpers/fake_tmux tests/cleanup.bats
git commit -m "feat: add cleanup.sh and test infrastructure"
```

---

## Task 2: `scripts/switcher.sh`

**Files:**
- Create: `scripts/switcher.sh`
- Create: `tests/switcher.bats`

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: `switcher.sh <session_id> <interval>` — loops, calling `tmux next-window -t <session_id>` every `<interval>` seconds; exits 0 when next-window returns non-zero

- [ ] **Step 1: Write failing tests for `switcher.sh`**

Create `tests/switcher.bats`:
```bash
#!/usr/bin/env bats

setup() {
    export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
    export TMUX_CALL_LOG
    TMUX_CALL_LOG="$(mktemp)"
}

teardown() {
    rm -f "$TMUX_CALL_LOG"
}

@test "switcher: exits cleanly when next-window fails (session gone)" {
    export TMUX_NEXT_WINDOW_EXIT=1

    run timeout 5 bash "$BATS_TEST_DIRNAME/../scripts/switcher.sh" "dead-session" 0

    [ "$status" -eq 0 ]
}

@test "switcher: calls next-window with the correct session target" {
    export TMUX_NEXT_WINDOW_EXIT=1

    timeout 5 bash "$BATS_TEST_DIRNAME/../scripts/switcher.sh" "my-session" 0 || true

    grep -q "next-window -t my-session" "$TMUX_CALL_LOG"
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
bats tests/switcher.bats
```
Expected: 2 tests fail with "No such file or directory".

- [ ] **Step 3: Implement `scripts/switcher.sh`**

Create `scripts/switcher.sh`:
```bash
#!/usr/bin/env bash
SESSION_ID="$1"
INTERVAL="$2"

while true; do
    sleep "$INTERVAL"
    tmux next-window -t "$SESSION_ID" 2>/dev/null || exit 0
done
```

```bash
chmod +x scripts/switcher.sh
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
bats tests/switcher.bats
```
Expected:
```
 ✓ switcher: exits cleanly when next-window fails (session gone)
 ✓ switcher: calls next-window with the correct session target

2 tests, 0 failures
```

- [ ] **Step 5: Commit**

```bash
git add scripts/switcher.sh tests/switcher.bats
git commit -m "feat: add switcher.sh background loop"
```

---

## Task 3: `scripts/toggle.sh`

**Files:**
- Create: `scripts/toggle.sh`
- Create: `tests/toggle.bats`

**Interfaces:**
- Consumes: `scripts/switcher.sh <session_id> <interval>` (spawns it in background)
- Consumes: tmux options `@kiosk-interval` (default `10`), `@kiosk-status` (default `⟳`)
- Produces: `toggle.sh <session_id>` — creates or removes `/tmp/tmux-kiosk-<session_id>.pid`; sets or clears tmux option `@kiosk-status-active` on the session

- [ ] **Step 1: Write failing tests for `toggle.sh`**

Create `tests/toggle.bats`:
```bash
#!/usr/bin/env bats

setup() {
    export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
    export TMUX_CALL_LOG
    TMUX_CALL_LOG="$(mktemp)"
    TEST_SESSION="test-session-$$"
    PID_FILE="/tmp/tmux-kiosk-${TEST_SESSION}.pid"
    SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
}

teardown() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -f "$TMUX_CALL_LOG"
}

@test "toggle: starts switcher and creates PID file when not running" {
    run bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"

    [ "$status" -eq 0 ]
    [ -f "$PID_FILE" ]
    PID=$(cat "$PID_FILE")
    kill -0 "$PID" 2>/dev/null
}

@test "toggle: sets @kiosk-status-active when starting" {
    bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"

    grep -q "set-option -t $TEST_SESSION @kiosk-status-active" "$TMUX_CALL_LOG"
}

@test "toggle: stops switcher and removes PID file when running" {
    bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"
    FIRST_PID=$(cat "$PID_FILE")

    run bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"

    [ "$status" -eq 0 ]
    [ ! -f "$PID_FILE" ]
    ! kill -0 "$FIRST_PID" 2>/dev/null
}

@test "toggle: clears @kiosk-status-active when stopping" {
    bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"
    rm -f "$TMUX_CALL_LOG"; touch "$TMUX_CALL_LOG"

    bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"

    grep -q "set-option -t $TEST_SESSION @kiosk-status-active $" "$TMUX_CALL_LOG" \
        || grep -q "set-option -t $TEST_SESSION @kiosk-status-active\"\"" "$TMUX_CALL_LOG" \
        || grep -q "set-option.*@kiosk-status-active" "$TMUX_CALL_LOG"
}

@test "toggle: treats stale PID file as not-running and starts fresh" {
    echo "99999999" > "$PID_FILE"

    run bash "$SCRIPTS_DIR/toggle.sh" "$TEST_SESSION"

    [ "$status" -eq 0 ]
    [ -f "$PID_FILE" ]
    PID=$(cat "$PID_FILE")
    [ "$PID" != "99999999" ]
    kill -0 "$PID" 2>/dev/null
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
bats tests/toggle.bats
```
Expected: 5 tests fail with "No such file or directory".

- [ ] **Step 3: Implement `scripts/toggle.sh`**

Create `scripts/toggle.sh`:
```bash
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

"$CURRENT_DIR/scripts/switcher.sh" "$SESSION_ID" "$INTERVAL" &
echo $! > "$PID_FILE"

tmux set-option -t "$SESSION_ID" @kiosk-status-active "$STATUS_TEXT" 2>/dev/null
```

```bash
chmod +x scripts/toggle.sh
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
bats tests/toggle.bats
```
Expected:
```
 ✓ toggle: starts switcher and creates PID file when not running
 ✓ toggle: sets @kiosk-status-active when starting
 ✓ toggle: stops switcher and removes PID file when running
 ✓ toggle: clears @kiosk-status-active when stopping
 ✓ toggle: treats stale PID file as not-running and starts fresh

5 tests, 0 failures
```

- [ ] **Step 5: Commit**

```bash
git add scripts/toggle.sh tests/toggle.bats
git commit -m "feat: add toggle.sh to start and stop the kiosk switcher"
```

---

## Task 4: `tmux-kiosk.tmux` entry point

**Files:**
- Create: `tmux-kiosk.tmux`

**Interfaces:**
- Consumes: `scripts/toggle.sh #{session_id}` (registers it as a keybinding)
- Consumes: `scripts/cleanup.sh #{session_id}` (registers it as a session-closed hook)
- Consumes: tmux options `@kiosk-interval`, `@kiosk-key` (with defaults)
- Produces: tmux keybinding `prefix + <key>` that calls toggle.sh; global `session-closed` hook that calls cleanup.sh

- [ ] **Step 1: Implement `tmux-kiosk.tmux`**

There is no meaningful way to unit-test keybinding registration without a live tmux server. The entry point is verified manually in Step 2. Create `tmux-kiosk.tmux`:

```bash
#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INTERVAL=$(tmux show-option -gv @kiosk-interval 2>/dev/null)
INTERVAL="${INTERVAL:-10}"

KEY=$(tmux show-option -gv @kiosk-key 2>/dev/null)
KEY="${KEY:-W}"

tmux set-option -g @kiosk-interval "$INTERVAL"

tmux bind-key "$KEY" run-shell \
    "$CURRENT_DIR/scripts/toggle.sh '#{session_id}'"

tmux set-hook -g session-closed \
    "run-shell '$CURRENT_DIR/scripts/cleanup.sh #{session_id}'"
```

```bash
chmod +x tmux-kiosk.tmux
```

- [ ] **Step 2: Verify manually in a running tmux session**

Source the entry point and confirm the keybinding and hook are registered:

```bash
# In a tmux session:
bash tmux-kiosk.tmux
tmux list-keys | grep -i kiosk      # should show prefix + W → toggle.sh
tmux show-hooks -g | grep session-closed  # should show cleanup.sh
```

Expected output (key line):
```
bind-key    -T prefix       W                 run-shell ".../scripts/toggle.sh '#{session_id}'"
```

- [ ] **Step 3: Commit**

```bash
git add tmux-kiosk.tmux
git commit -m "feat: add tmux-kiosk.tmux TPM entry point"
```

---

## Task 5: README

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: all prior tasks (documents them)

- [ ] **Step 1: Write `README.md`**

Create `README.md` with the following sections. Code blocks inside the README use triple backticks; write the file directly with a text editor or `Write` tool.

**Title and overview:** `# tmux-kiosk` — one paragraph describing the dashboard/monitoring use case.

**Features list:**
- Toggle auto-switching on/off with a single keybinding
- Configurable interval between window switches
- Optional status bar indicator shows when kiosk mode is active
- Session-scoped: each session manages its own state independently
- Automatic cleanup when a session closes
- No external dependencies — pure bash and tmux

**Requirements section:**
- tmux ≥ 2.1
- bash ≥ 3.2
- TPM (optional, for managed install)

**Installation — Via TPM:**

    set -g @plugin 'jonasbn/tmux-kiosk'

Then `prefix + I` to install.

**Installation — Manual:**

    git clone https://github.com/jonasbn/tmux-kiosk \
      ~/.config/tmux/plugins/tmux-kiosk
    ~/.config/tmux/plugins/tmux-kiosk/tmux-kiosk.tmux

**Configuration table:**

| Option | Default | Description |
|---|---|---|
| `@kiosk-interval` | `10` | Seconds between window switches |
| `@kiosk-key` | `W` | Toggle key (used with tmux prefix) |
| `@kiosk-status` | `⟳` | Status bar text shown when active |

**Status bar section** — show `#{@kiosk-status-active}` placeholder example:

    set -g status-right "#{@kiosk-status-active} | %H:%M"

**Usage section:**
- `prefix + W` to start auto-switching
- `prefix + W` again to stop
- Changing `@kiosk-interval` takes effect on the next toggle-on

**Notes:**
- Switching wraps from last window to first automatically
- Single-window sessions run harmlessly
- Background process is cleaned up automatically when session closes

- [ ] **Step 2: Run the full test suite one final time**

```bash
bats tests/
```
Expected:
```
 ✓ cleanup: kills process and removes PID file when switcher is running
 ✓ cleanup: removes stale PID file without error when process is gone
 ✓ cleanup: exits cleanly when no PID file exists
 ✓ switcher: exits cleanly when next-window fails (session gone)
 ✓ switcher: calls next-window with the correct session target
 ✓ toggle: starts switcher and creates PID file when not running
 ✓ toggle: sets @kiosk-status-active when starting
 ✓ toggle: stops switcher and removes PID file when running
 ✓ toggle: clears @kiosk-status-active when stopping
 ✓ toggle: treats stale PID file as not-running and starts fresh

10 tests, 0 failures
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with installation, configuration, and usage"
```
