#!/usr/bin/env bats

load helpers/tmux_mock

setup() {
    mock_setup
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    TOGGLE_SCRIPT="$SCRIPT_DIR/utils/sidebar-toggle.sh"

    cat > "$TMUX_MOCK_DIR/bin/tmux" <<'MOCK'
#!/bin/bash
set -euo pipefail

STORE="$TMUX_MOCK_DIR/store"
mkdir -p "$STORE"

log_split() {
    printf '%s\n' "$*" >> "$TMUX_MOCK_DIR/split_log"
}

cmd="$1"
shift

case "$cmd" in
    display-message)
        target="$TMUX_PANE"
        format=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -t)
                    shift
                    target="$1"
                    ;;
                -p)
                    ;;
                *)
                    format="$1"
                    ;;
            esac
            shift
        done

        case "$format" in
            '#{@sidebar_width}') printf '%s' "${TMUX_MOCK_SIDEBAR_WIDTH:-20%}" ;;
            '#{window_width}') printf '%s' "${TMUX_MOCK_WINDOW_WIDTH:-200}" ;;
            '#{pane_id}') printf '%s' "${TMUX_MOCK_ACTIVE_PANE:-%0}" ;;
            *)
                printf '%s' "$format"
                ;;
        esac
        ;;
    list-panes)
        fmt=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -F)
                    shift
                    fmt="$1"
                    ;;
                -t)
                    shift
                    ;;
                *)
                    ;;
            esac
            shift
        done

        case "$fmt" in
            '#{pane_id}|#{@pane_role}')
                printf '%s\n' "${TMUX_MOCK_LIST_PANES_ROLES:-%1|agent}"
                ;;
            '#{pane_left} #{pane_id}')
                printf '%s\n' "${TMUX_MOCK_LIST_PANES_LEFT:-0 %1}"
                ;;
            *)
                printf '%s\n' "${TMUX_MOCK_LIST_PANES:-}"
                ;;
        esac
        ;;
    split-window)
        log_split "$*"
        printf '%s' "${TMUX_MOCK_SPLIT_PANE:-%9}"
        ;;
    set|select-pane|kill-pane)
        ;;
    *)
        ;;
esac
MOCK
    chmod +x "$TMUX_MOCK_DIR/bin/tmux"
}

teardown() {
    mock_teardown
}

@test "sidebar-toggle.sh converts percent width from window width" {
    export TMUX_MOCK_WINDOW_WIDTH=200
    export TMUX_MOCK_SIDEBAR_WIDTH=20%
    export TMUX_MOCK_ACTIVE_PANE=%0
    export TMUX_MOCK_LIST_PANES_ROLES="%1|agent"
    export TMUX_MOCK_LIST_PANES_LEFT="0 %1"

    bash "$TOGGLE_SCRIPT" "@1" "$HOME"

    grep -q -- '-l 40 ' "$TMUX_MOCK_DIR/split_log"
}

@test "sidebar-toggle.sh keeps fixed width unchanged" {
    export TMUX_MOCK_SIDEBAR_WIDTH=32
    export TMUX_MOCK_LIST_PANES_ROLES="%1|agent"
    export TMUX_MOCK_LIST_PANES_LEFT="0 %1"

    bash "$TOGGLE_SCRIPT" "@1" "$HOME"

    grep -q -- '-l 32 ' "$TMUX_MOCK_DIR/split_log"
}
