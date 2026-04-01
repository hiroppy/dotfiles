#!/bin/bash
# Usage: popup-icon.sh <pane_current_path>
# Outputs: running / idle / popup (session exists but no agent) / (empty)

session="popup_$(basename "$1")"
tmux has-session -t "$session" 2>/dev/null || exit 0

result=$("$(dirname "$0")/check-agent-status.sh" "$session")

if [ -n "$result" ]; then
    echo "$result"
else
    echo "popup"
fi
