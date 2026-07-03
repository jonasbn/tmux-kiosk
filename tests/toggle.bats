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
