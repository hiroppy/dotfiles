#!/usr/bin/env bats

load helpers/tmux_mock

setup() {
    mock_setup
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

teardown() {
    mock_teardown
}

@test "agent-status.sh running sets @pane_status to running" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "running" ]
}

@test "agent-status.sh waiting sets @pane_status to waiting" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" waiting
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "waiting" ]
}

@test "agent-status.sh idle sets @pane_status to idle" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" idle
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
}

@test "agent-status.sh clear unsets @pane_status" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    bash "$SCRIPT_DIR/utils/agent-status.sh" clear
    mock_option_unset "$TMUX_PANE" "@pane_status"
}

@test "agent-status.sh clear unsets @pane_attention" {
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" clear
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "agent-status.sh running clears @pane_attention" {
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "agent-status.sh waiting preserves @pane_attention" {
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" waiting
    result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$result" = "notification" ]
}

@test "agent-status.sh idle clears @pane_attention" {
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" idle
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "agent-status.sh with no args does nothing" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" ""
    mock_option_unset "$TMUX_PANE" "@pane_status"
}

@test "agent-status.sh without TMUX_PANE does nothing" {
    unset TMUX_PANE
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    # No crash, no store file
    [ ! -f "$TMUX_MOCK_DIR/store/_0" ]
}

# Status transition tests for claude/codex workflow
@test "transition: waiting -> running clears attention and updates status" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" waiting
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "running" ]
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "transition: running -> waiting updates status" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    bash "$SCRIPT_DIR/utils/agent-status.sh" waiting
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "waiting" ]
}

@test "transition: running -> idle updates status" {
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    bash "$SCRIPT_DIR/utils/agent-status.sh" idle
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
}

# Bug fix: waiting should NOT clear attention (it's the state where attention is needed)
@test "transition: running -> waiting preserves existing attention" {
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" running
    # running clears attention
    mock_option_unset "$TMUX_PANE" "@pane_attention"
    # set attention again, then go to waiting
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" waiting
    # waiting must preserve attention
    result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$result" = "notification" ]
}

@test "transition: error status does not clear attention" {
    tmux set -t "$TMUX_PANE" -p @pane_attention notification
    bash "$SCRIPT_DIR/utils/agent-status.sh" error
    result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$result" = "notification" ]
}
