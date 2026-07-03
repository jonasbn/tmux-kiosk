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
