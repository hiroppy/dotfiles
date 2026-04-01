#!/bin/bash
# Usage: pane-icon.sh <pane_id>
# Outputs: running / idle / (empty)

pane_id="$1"
[ -z "$pane_id" ] && exit 0

has_idle=false

while IFS= read -r status; do
    if [ "$status" = "running" ]; then
        echo "running"
        exit 0
    fi
    [ "$status" = "idle" ] && has_idle=true
done < <(tmux list-panes -t "$pane_id" -F '#{@pane_status}' 2>/dev/null)

$has_idle && echo "idle"
