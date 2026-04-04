#!/usr/bin/env bats

load helpers/tmux_mock

setup() {
    mock_setup
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HOOK_SCRIPT="$SCRIPT_DIR/hook.sh"
    # Stub notify (fish may not be available)
    mkdir -p "$TMUX_MOCK_DIR/bin"
    printf '#!/bin/bash\nexit 0\n' > "$TMUX_MOCK_DIR/bin/fish"
    chmod +x "$TMUX_MOCK_DIR/bin/fish"
}

teardown() {
    mock_teardown
}

# --- Claude hooks ---

@test "claude: user-prompt-submit sets status to running" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "running" ]
}

@test "claude: notification sets status to waiting" {
    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "waiting" ]
}

@test "claude: notification sets attention" {
    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$result" = "notification" ]
}

@test "claude: stop sets status to idle" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    echo "{}" | bash "$HOOK_SCRIPT" claude stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
}

@test "claude: stop clears attention" {
    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    echo "{}" | bash "$HOOK_SCRIPT" claude stop
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "claude: user-prompt-submit clears attention from notification" {
    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "claude: session-start sets idle and clears attention" {
    echo "{}" | bash "$HOOK_SCRIPT" claude session-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

@test "claude: session-start clears stale prompt and run state" {
    echo '{"prompt":"old task"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    # Verify stale data exists
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "old task" ]
    result="$(mock_get_option "$TMUX_PANE" "@pane_started_at")"
    [ -n "$result" ]
    # session-start should clear it all
    echo "{}" | bash "$HOOK_SCRIPT" claude session-start
    mock_option_unset "$TMUX_PANE" "@pane_prompt"
    mock_option_unset "$TMUX_PANE" "@pane_started_at"
    mock_option_unset "$TMUX_PANE" "@pane_wait_reason"
}

@test "claude: session-end clears status and attention" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    echo "{}" | bash "$HOOK_SCRIPT" claude session-end
    mock_option_unset "$TMUX_PANE" "@pane_status"
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

# --- Full lifecycle: running -> waiting -> running -> idle ---

@test "claude: full lifecycle running->notification->submit->stop" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "running" ]

    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "waiting" ]

    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "running" ]
    mock_option_unset "$TMUX_PANE" "@pane_attention"

    echo "{}" | bash "$HOOK_SCRIPT" claude stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
}

# --- Codex hooks ---

@test "codex: user-prompt-submit sets status to running" {
    echo "{}" | bash "$HOOK_SCRIPT" codex user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "running" ]
}

@test "codex: stop sets status to idle" {
    echo "{}" | bash "$HOOK_SCRIPT" codex user-prompt-submit
    echo "{}" | bash "$HOOK_SCRIPT" codex stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
}

@test "codex: session-start sets idle" {
    echo "{}" | bash "$HOOK_SCRIPT" codex session-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "idle" ]
}

# --- Agent meta ---

@test "claude: sets @pane_agent to claude" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_agent")"
    [ "$result" = "claude" ]
}

@test "codex: sets @pane_agent to codex" {
    echo "{}" | bash "$HOOK_SCRIPT" codex user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_agent")"
    [ "$result" = "codex" ]
}

# --- Edge cases ---

@test "unknown agent does nothing" {
    run bash -c 'echo "{}" | bash "$1" unknown notification' _ "$HOOK_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "empty args does nothing" {
    run bash -c 'echo "{}" | bash "$1" "" ""' _ "$HOOK_SCRIPT"
    [ "$status" -eq 0 ]
}

# --- Bug fix tests ---

@test "codex: stop outputs continue:true" {
    output="$(echo '{}' | bash "$HOOK_SCRIPT" codex stop)"
    [[ "$output" == *'{"continue":true}'* ]]
}

@test "claude: stop does not output continue:true" {
    output="$(echo '{}' | bash "$HOOK_SCRIPT" claude stop)"
    [[ "$output" != *'{"continue":true}'* ]]
}

@test "claude: session-end clears @pane_agent" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_agent")"
    [ "$result" = "claude" ]
    echo "{}" | bash "$HOOK_SCRIPT" claude session-end
    mock_option_unset "$TMUX_PANE" "@pane_agent"
}

@test "claude: notification sets waiting AND preserves attention" {
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    status_result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    attention_result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$status_result" = "waiting" ]
    [ "$attention_result" = "notification" ]
}

@test "claude: user-prompt-submit after notification restores running and clears attention" {
    echo "{}" | bash "$HOOK_SCRIPT" claude notification
    echo "{}" | bash "$HOOK_SCRIPT" claude user-prompt-submit
    status_result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$status_result" = "running" ]
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

# --- Prompt display tests ---

@test "claude: user-prompt-submit saves prompt from stdin JSON" {
    echo '{"prompt":"テストを実行して"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "テストを実行して" ]
}

@test "claude: user-prompt-submit with empty prompt does not set @pane_prompt" {
    echo '{}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    mock_option_unset "$TMUX_PANE" "@pane_prompt"
}

@test "claude: session-end clears @pane_prompt" {
    echo '{"prompt":"hello"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "hello" ]
    echo "{}" | bash "$HOOK_SCRIPT" claude session-end
    mock_option_unset "$TMUX_PANE" "@pane_prompt"
}

@test "codex: user-prompt-submit saves prompt" {
    echo '{"prompt":"fix the bug"}' | bash "$HOOK_SCRIPT" codex user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "fix the bug" ]
}

# --- Wait reason tests ---

@test "claude: notification saves wait reason from notification_type" {
    echo '{"notification_type":"permission_prompt"}' | bash "$HOOK_SCRIPT" claude notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_wait_reason")"
    [ "$result" = "permission_prompt" ]
}

@test "claude: user-prompt-submit clears wait reason" {
    echo '{"notification_type":"permission_prompt"}' | bash "$HOOK_SCRIPT" claude notification
    echo '{}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    mock_option_unset "$TMUX_PANE" "@pane_wait_reason"
}

@test "claude: stop clears wait reason" {
    echo '{"notification_type":"idle_prompt"}' | bash "$HOOK_SCRIPT" claude notification
    echo '{}' | bash "$HOOK_SCRIPT" claude stop
    mock_option_unset "$TMUX_PANE" "@pane_wait_reason"
}

@test "claude: stop-failure sets error status and rate limit wait reason" {
    echo '{"error":"rate_limit","error_details":"429 Too Many Requests"}' \
        | bash "$HOOK_SCRIPT" claude stop-failure
    status_result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    wait_reason_result="$(mock_get_option "$TMUX_PANE" "@pane_wait_reason")"
    [ "$status_result" = "error" ]
    [ "$wait_reason_result" = "rate_limit" ]
}

@test "claude: session-end clears wait reason" {
    echo '{"notification_type":"permission_prompt"}' | bash "$HOOK_SCRIPT" claude notification
    echo '{}' | bash "$HOOK_SCRIPT" claude session-end
    mock_option_unset "$TMUX_PANE" "@pane_wait_reason"
}

# --- Started-at timestamp tests ---

@test "claude: user-prompt-submit sets @pane_started_at" {
    echo '{}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_started_at")"
    [ -n "$result" ]
    # Should be a reasonable unix timestamp
    [ "$result" -gt 1000000000 ]
}

@test "claude: stop clears @pane_started_at" {
    echo '{}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_started_at")"
    [ -n "$result" ]
    echo '{}' | bash "$HOOK_SCRIPT" claude stop
    mock_option_unset "$TMUX_PANE" "@pane_started_at"
}

@test "claude: session-end clears @pane_started_at" {
    echo '{}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    echo '{}' | bash "$HOOK_SCRIPT" claude session-end
    mock_option_unset "$TMUX_PANE" "@pane_started_at"
}

@test "codex: user-prompt-submit sets @pane_started_at" {
    echo '{}' | bash "$HOOK_SCRIPT" codex user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_started_at")"
    [ -n "$result" ]
    [ "$result" -gt 1000000000 ]
}

# --- Codex-specific tests ---

@test "codex: notification sets status to waiting" {
    echo '{}' | bash "$HOOK_SCRIPT" codex notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_status")"
    [ "$result" = "waiting" ]
}

@test "codex: notification sets attention" {
    echo '{}' | bash "$HOOK_SCRIPT" codex notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$result" = "notification" ]
}

@test "codex: session-end clears all metadata" {
    echo '{}' | bash "$HOOK_SCRIPT" codex user-prompt-submit
    echo '{}' | bash "$HOOK_SCRIPT" codex session-end
    mock_option_unset "$TMUX_PANE" "@pane_status"
    mock_option_unset "$TMUX_PANE" "@pane_agent"
    mock_option_unset "$TMUX_PANE" "@pane_started_at"
}

# --- TMUX_PANE unset tests ---

@test "hook: works without TMUX_PANE (no crash)" {
    unset TMUX_PANE
    run bash -c 'echo "{}" | bash "$1" claude user-prompt-submit' _ "$HOOK_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "hook: unknown event exits cleanly" {
    run bash -c 'echo "{}" | bash "$1" claude unknown-event' _ "$HOOK_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "claude: session-end removes activity log file" {
    local log_file="/tmp/tmux-agent-activity${TMUX_PANE//%/_}.log"
    echo "test" > "$log_file"
    [ -f "$log_file" ]
    echo "{}" | bash "$HOOK_SCRIPT" claude session-end
    [ ! -f "$log_file" ]
}

@test "codex: session-end removes activity log file" {
    local log_file="/tmp/tmux-agent-activity${TMUX_PANE//%/_}.log"
    echo "test" > "$log_file"
    [ -f "$log_file" ]
    echo "{}" | bash "$HOOK_SCRIPT" codex session-end
    [ ! -f "$log_file" ]
}

@test "hook: session-end with no activity log file exits cleanly" {
    local log_file="/tmp/tmux-agent-activity${TMUX_PANE//%/_}.log"
    [ ! -f "$log_file" ]
    run bash -c 'echo "{}" | bash "$1" claude session-end' _ "$HOOK_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "hook: session-end without TMUX_PANE does not delete arbitrary log files" {
    local sentinel="/tmp/tmux-agent-activity.log"
    echo "keep" > "$sentinel"
    unset TMUX_PANE
    bash -c 'echo "{}" | bash "$1" claude session-end' _ "$HOOK_SCRIPT" || true
    [ -f "$sentinel" ]
    rm -f "$sentinel"
}

@test "hook: codex stop after notification clears attention" {
    echo '{}' | bash "$HOOK_SCRIPT" codex notification
    result="$(mock_get_option "$TMUX_PANE" "@pane_attention")"
    [ "$result" = "notification" ]
    echo '{}' | bash "$HOOK_SCRIPT" codex stop
    mock_option_unset "$TMUX_PANE" "@pane_attention"
}

# --- Prompt filtering tests ---

@test "claude: user-prompt-submit skips prompt containing XML tags" {
    # Set an initial prompt
    echo '{"prompt":"original prompt"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "original prompt" ]
    # XML-containing prompt should be skipped, keeping previous value
    echo '{"prompt":"hello <task-notification><task-id>abc</task-id></task-notification> world"}' \
        | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "original prompt" ]
}

@test "claude: user-prompt-submit skips system-reminder prompt" {
    echo '{"prompt":"real prompt"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    echo '{"prompt":"<system-reminder>noise</system-reminder>"}' \
        | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "real prompt" ]
}

@test "claude: stop sets last_assistant_message as response prompt" {
    echo '{"last_assistant_message":"task completed"}' \
        | bash "$HOOK_SCRIPT" claude stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    expected="$(printf '\xe2\x9d\xaf\xc2\xa0')task completed"
    [ "$result" = "$expected" ]
}

@test "claude: prompt without XML tags is unchanged" {
    echo '{"prompt":"plain text prompt"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    [ "$result" = "plain text prompt" ]
}

# --- Subagent lifecycle tests ---

@test "claude: subagent-start adds subagent" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore" ]
}

@test "claude: subagent-stop keeps subagent visible until all done" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Plan"}' | bash "$HOOK_SCRIPT" claude subagent-start
    # First subagent completes — both still visible
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore,Plan" ]
    # All subagents complete — cleared
    echo '{"agent_type":"Plan"}' | bash "$HOOK_SCRIPT" claude subagent-stop
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: single subagent cleared on subagent-stop" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-stop
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: stop clears subagents" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore" ]
    echo '{}' | bash "$HOOK_SCRIPT" claude stop
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: stop-failure clears subagents" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore" ]
    echo '{"error":"rate_limit"}' | bash "$HOOK_SCRIPT" claude stop-failure
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: session-start clears subagents" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore" ]
    echo '{}' | bash "$HOOK_SCRIPT" claude session-start
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: multiple subagents numbered correctly" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore #1,Explore #2" ]
}

@test "claude: 3 subagents visible until all 3 complete" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Plan"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore #1,Plan,Explore #2" ]
    # 1 done
    echo '{}' | bash "$HOOK_SCRIPT" claude subagent-stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore #1,Plan,Explore #2" ]
    # 2 done
    echo '{}' | bash "$HOOK_SCRIPT" claude subagent-stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore #1,Plan,Explore #2" ]
    # 3 done — all cleared
    echo '{}' | bash "$HOOK_SCRIPT" claude subagent-stop
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: subagent done counter cleared on stop" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Plan"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{}' | bash "$HOOK_SCRIPT" claude subagent-stop
    # stop clears everything including done counter
    echo '{}' | bash "$HOOK_SCRIPT" claude stop
    mock_option_unset "$TMUX_PANE" "@pane_subagents_done"
}

@test "claude: subagent-stop counts towards total regardless of type" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" claude subagent-start
    echo '{"agent_type":"Plan"}' | bash "$HOOK_SCRIPT" claude subagent-start
    # One completes
    echo '{"agent_type":"Plan"}' | bash "$HOOK_SCRIPT" claude subagent-stop
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore,Plan" ]
    done="$(mock_get_option "$TMUX_PANE" "@pane_subagents_done")"
    [ "$done" = "1" ]
}

@test "codex: stop clears subagents" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" codex subagent-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_subagents")"
    [ "$result" = "Explore" ]
    echo '{}' | bash "$HOOK_SCRIPT" codex stop
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "codex: stop-failure clears subagents" {
    echo '{"agent_type":"Explore"}' | bash "$HOOK_SCRIPT" codex subagent-start
    echo '{"error":"crash"}' | bash "$HOOK_SCRIPT" codex stop-failure
    mock_option_unset "$TMUX_PANE" "@pane_subagents"
}

@test "claude: prompt with angle brackets in code is skipped" {
    echo '{"prompt":"real prompt"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    echo '{"prompt":"fix the <div> tag"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_prompt")"
    # Contains < and > so it gets skipped
    [ "$result" = "real prompt" ]
}

# --- @pane_cwd tests ---

@test "claude: user-prompt-submit sets @pane_cwd from json cwd" {
    echo '{"cwd":"/home/user/worktree"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_cwd")"
    [ "$result" = "/home/user/worktree" ]
}

@test "codex: user-prompt-submit sets @pane_cwd from json cwd" {
    echo '{"cwd":"/home/user/worktree"}' | bash "$HOOK_SCRIPT" codex user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_cwd")"
    [ "$result" = "/home/user/worktree" ]
}

@test "claude: session-start sets @pane_cwd" {
    echo '{"cwd":"/home/user/project"}' | bash "$HOOK_SCRIPT" claude session-start
    result="$(mock_get_option "$TMUX_PANE" "@pane_cwd")"
    [ "$result" = "/home/user/project" ]
}

@test "claude: session-end clears @pane_cwd" {
    echo '{"cwd":"/home/user/project"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_cwd")"
    [ "$result" = "/home/user/project" ]
    echo "{}" | bash "$HOOK_SCRIPT" claude session-end
    mock_option_unset "$TMUX_PANE" "@pane_cwd"
}

@test "claude: empty cwd does not set @pane_cwd" {
    echo '{}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    mock_option_unset "$TMUX_PANE" "@pane_cwd"
}

@test "claude: @pane_cwd updates on each prompt" {
    echo '{"cwd":"/path/one"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_cwd")"
    [ "$result" = "/path/one" ]
    echo '{"cwd":"/path/two"}' | bash "$HOOK_SCRIPT" claude user-prompt-submit
    result="$(mock_get_option "$TMUX_PANE" "@pane_cwd")"
    [ "$result" = "/path/two" ]
}
