#!/usr/bin/env bats

load helpers/tmux_mock

setup() {
    mock_setup
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    # Track kill-window calls
    KILL_LOG="$TMUX_MOCK_DIR/kill_log"
    # Enhance mock to support list-panes with -F and kill-window
    cat > "$TMUX_MOCK_DIR/bin/tmux" <<'MOCK'
#!/bin/bash
set -euo pipefail

STORE="$TMUX_MOCK_DIR/store"
mkdir -p "$STORE"

cmd="$1"; shift

case "$cmd" in
    list-panes)
        target=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -t) shift; target="$1" ;;
                -F) shift ;; # ignore format
                *) ;;
            esac
            shift
        done
        [ -n "${TMUX_MOCK_LIST_PANES:-}" ] && printf '%s\n' "$TMUX_MOCK_LIST_PANES"
        ;;
    kill-window)
        target=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -t) shift; target="$1" ;;
                *) ;;
            esac
            shift
        done
        echo "killed:$target" >> "$TMUX_MOCK_DIR/kill_log"
        ;;
    *) ;;
esac
MOCK
    chmod +x "$TMUX_MOCK_DIR/bin/tmux"
}

teardown() {
    mock_teardown
}

@test "auto-close: empty window_id exits without error" {
    run bash "$SCRIPT_DIR/utils/auto-close.sh" ""
    [ "$status" -eq 0 ]
    [ ! -f "$KILL_LOG" ]
}

@test "auto-close: kills window when only sidebar panes remain" {
    export TMUX_MOCK_LIST_PANES="sidebar
sidebar"
    bash "$SCRIPT_DIR/utils/auto-close.sh" "@1"
    [ -f "$KILL_LOG" ]
    grep -q "killed:@1" "$KILL_LOG"
}

@test "auto-close: does not kill window when non-sidebar panes exist" {
    export TMUX_MOCK_LIST_PANES="sidebar
"
    bash "$SCRIPT_DIR/utils/auto-close.sh" "@1"
    [ ! -f "$KILL_LOG" ]
}

@test "auto-close: does not kill window with mixed pane roles" {
    export TMUX_MOCK_LIST_PANES="sidebar

sidebar"
    bash "$SCRIPT_DIR/utils/auto-close.sh" "@1"
    [ ! -f "$KILL_LOG" ]
}

@test "auto-close: does not kill window with only non-sidebar panes" {
    export TMUX_MOCK_LIST_PANES="

"
    bash "$SCRIPT_DIR/utils/auto-close.sh" "@1"
    [ ! -f "$KILL_LOG" ]
}

@test "auto-close: handles window with no panes gracefully" {
    unset TMUX_MOCK_LIST_PANES
    run bash "$SCRIPT_DIR/utils/auto-close.sh" "@1"
    [ "$status" -eq 0 ]
}
