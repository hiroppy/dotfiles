#!/usr/bin/env bats

load helpers/tmux_mock

setup() {
    mock_setup
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

teardown() {
    mock_teardown
}

@test "check-agent-status.sh returns running if any pane is running" {
    export TMUX_MOCK_LIST_PANES="running
idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "running" ]
}

@test "check-agent-status.sh returns idle if all panes are idle" {
    export TMUX_MOCK_LIST_PANES="idle
idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "idle" ]
}

@test "check-agent-status.sh returns running even with waiting panes" {
    export TMUX_MOCK_LIST_PANES="waiting
running
idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "running" ]
}

@test "check-agent-status.sh returns empty if no panes have status" {
    unset TMUX_MOCK_LIST_PANES
    run bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0"
    [ -z "$output" ]
}

@test "check-agent-status.sh with no target does nothing" {
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "")"
    [ -z "$result" ]
}

# Bug: waiting status was not recognized
@test "check-agent-status.sh returns waiting if any pane is waiting and none running" {
    export TMUX_MOCK_LIST_PANES="waiting
idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "waiting" ]
}

@test "check-agent-status.sh returns waiting if all panes are waiting" {
    export TMUX_MOCK_LIST_PANES="waiting
waiting"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "waiting" ]
}

@test "check-agent-status.sh priority: running > waiting > idle" {
    export TMUX_MOCK_LIST_PANES="idle
waiting
running"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "running" ]
}

@test "check-agent-status.sh returns error if any pane has error" {
    export TMUX_MOCK_LIST_PANES="idle
error
waiting"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "error" ]
}

@test "check-agent-status.sh treats notification as waiting" {
    export TMUX_MOCK_LIST_PANES="notification
idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "waiting" ]
}

@test "check-agent-status.sh priority: error > waiting (error before waiting)" {
    export TMUX_MOCK_LIST_PANES="error
waiting"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "error" ]
}

@test "check-agent-status.sh priority: error > waiting (waiting before error)" {
    export TMUX_MOCK_LIST_PANES="waiting
error"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "error" ]
}

@test "check-agent-status.sh single pane running" {
    export TMUX_MOCK_LIST_PANES="running"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "running" ]
}

@test "check-agent-status.sh single pane idle" {
    export TMUX_MOCK_LIST_PANES="idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "idle" ]
}

@test "check-agent-status.sh ignores unknown statuses" {
    export TMUX_MOCK_LIST_PANES="unknown
idle"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ "$result" = "idle" ]
}

@test "check-agent-status.sh returns empty for only unknown statuses" {
    export TMUX_MOCK_LIST_PANES="unknown
something"
    result="$(bash "$SCRIPT_DIR/../tmux/scripts/check-agent-status.sh" "%0")"
    [ -z "$result" ]
}
