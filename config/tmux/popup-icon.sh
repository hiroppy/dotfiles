#!/bin/bash
# Usage: popup-icon.sh <pane_current_path>
# Outputs: running / idle / popup (session exists but no agent) / (empty)

session="popup_$(basename "$1")"
tmux has-session -t "$session" 2>/dev/null || exit 0

has_idle=false

while IFS= read -r status; do
    if [ "$status" = "running" ]; then
        echo "running"
        exit 0
    fi
    [ "$status" = "idle" ] && has_idle=true
done < <(tmux list-panes -t "$session" -F '#{@pane_status}' 2>/dev/null)

if $has_idle; then
    echo "idle"
else
    echo "popup"
fi
