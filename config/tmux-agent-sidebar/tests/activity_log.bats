#!/usr/bin/env bats

load helpers/tmux_mock

setup() {
    mock_setup
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    LOG_SCRIPT="$SCRIPT_DIR/activity-log.sh"
    export TMUX_PANE="%5"
    LOG_FILE="/tmp/tmux-agent-activity_5.log"
    rm -f "$LOG_FILE"
}

teardown() {
    rm -f "$LOG_FILE" "${LOG_FILE}.tmp"
    mock_teardown
}

@test "activity-log: creates log file with tool entry" {
    echo '{"tool_name":"Read","tool_input":{"file_path":"/home/user/src/main.ts"}}' \
        | bash "$LOG_SCRIPT"
    [ -f "$LOG_FILE" ]
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Read|main.ts"* ]]
}

@test "activity-log: extracts basename for Edit tool" {
    echo '{"tool_name":"Edit","tool_input":{"file_path":"/home/user/project/utils/helper.py"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Edit|helper.py"* ]]
}

@test "activity-log: extracts command for Bash tool" {
    echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Bash|npm test"* ]]
}

@test "activity-log: preserves full Bash commands" {
    local long_cmd="npm run test -- --watch --coverage --verbose --maxWorkers=4"
    echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$long_cmd\"}}" \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Bash|$long_cmd"* ]]
}

@test "activity-log: extracts pattern for Glob tool" {
    echo '{"tool_name":"Glob","tool_input":{"pattern":"**/*.ts"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Glob|**/*.ts"* ]]
}

@test "activity-log: extracts pattern for Grep tool" {
    echo '{"tool_name":"Grep","tool_input":{"pattern":"TODO"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Grep|TODO"* ]]
}

@test "activity-log: extracts description for Agent tool" {
    echo '{"tool_name":"Agent","tool_input":{"description":"explore codebase"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Agent|explore codebase"* ]]
}

@test "activity-log: handles Write tool" {
    echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/new-file.js"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Write|new-file.js"* ]]
}

@test "activity-log: unknown tool logs with empty label" {
    echo '{"tool_name":"WebSearch","tool_input":{}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|WebSearch|"* ]]
}

@test "activity-log: appends multiple entries" {
    echo '{"tool_name":"Read","tool_input":{"file_path":"/a/b.ts"}}' | bash "$LOG_SCRIPT"
    echo '{"tool_name":"Edit","tool_input":{"file_path":"/a/c.ts"}}' | bash "$LOG_SCRIPT"
    count="$(wc -l < "$LOG_FILE")"
    [ "$count" -eq 2 ]
}

@test "activity-log: does nothing without TMUX_PANE" {
    unset TMUX_PANE
    run bash -c 'echo "{\"tool_name\":\"Read\",\"tool_input\":{}}" | bash "$1"' _ "$LOG_SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "$LOG_FILE" ]
}

@test "activity-log: does nothing without tool_name" {
    echo '{"tool_input":{}}' | bash "$LOG_SCRIPT"
    [ ! -f "$LOG_FILE" ]
}

@test "activity-log: keeps max 50 lines" {
    for i in $(seq 1 55); do
        echo "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/a/file${i}.ts\"}}" \
            | bash "$LOG_SCRIPT"
    done
    count="$(wc -l < "$LOG_FILE")"
    [ "$count" -le 50 ]
}

@test "activity-log: keeps the LAST 50 entries when over limit" {
    for i in $(seq 1 55); do
        echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cmd${i}\"}}" \
            | bash "$LOG_SCRIPT"
    done
    # First 5 entries should be gone; entry 6 onward should remain
    ! grep -q "|Bash|cmd1$" "$LOG_FILE"
    ! grep -q "|Bash|cmd5$" "$LOG_FILE"
    grep -q "|Bash|cmd6$" "$LOG_FILE"
    grep -q "|Bash|cmd55$" "$LOG_FILE"
}

@test "activity-log: empty stdin produces no log file" {
    bash "$LOG_SCRIPT" < /dev/null
    [ ! -f "$LOG_FILE" ]
}

@test "activity-log: malformed JSON produces no log file" {
    echo 'not-valid-json' | bash "$LOG_SCRIPT"
    [ ! -f "$LOG_FILE" ]
}

@test "activity-log: bare filename (no directory) is preserved" {
    echo '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    [[ "$line" == *"|Read|README.md"* ]]
}

@test "activity-log: multiline Bash command is collapsed to single line" {
    local cmd='git commit -m "$(cat <<'\''EOF'\''
message line 1
line 2
EOF
)"'
    echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(jq -n --arg c "$cmd" '$c')}}" \
        | bash "$LOG_SCRIPT"
    count="$(wc -l < "$LOG_FILE")"
    [ "$count" -eq 1 ]
}

@test "activity-log: pipe character in label is replaced with space" {
    echo '{"tool_name":"Bash","tool_input":{"command":"cat file | grep foo"}}' \
        | bash "$LOG_SCRIPT"
    line="$(cat "$LOG_FILE")"
    # Should not contain a pipe in the label portion
    local label="${line#*|Bash|}"
    [[ "$label" != *"|"* ]]
}

@test "activity-log: TMUX_PANE value is used in log filename" {
    export TMUX_PANE="%42"
    local expected_file="/tmp/tmux-agent-activity_42.log"
    rm -f "$expected_file"
    echo '{"tool_name":"Read","tool_input":{"file_path":"/a/b.ts"}}' | bash "$LOG_SCRIPT"
    [ -f "$expected_file" ]
    rm -f "$expected_file"
}
