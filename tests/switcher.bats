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
