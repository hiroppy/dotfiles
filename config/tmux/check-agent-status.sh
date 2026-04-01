#!/bin/bash
# Usage: check-agent-status.sh <target>
# Outputs: running / idle / (empty)
# Checks @pane_status across all panes in the target (pane_id or session).

target="$1"
[ -z "$target" ] && exit 0

has_idle=false

while IFS= read -r status; do
    if [ "$status" = "running" ]; then
        echo "running"
        exit 0
    fi
    [ "$status" = "idle" ] && has_idle=true
done < <(tmux list-panes -t "$target" -F '#{@pane_status}' 2>/dev/null)

$has_idle && echo "idle"
