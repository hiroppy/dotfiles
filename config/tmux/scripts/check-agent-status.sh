#!/bin/bash
# Usage: check-agent-status.sh <target>
# Outputs: running / waiting / error / idle / (empty)
# Checks @pane_status across all panes in the target (pane_id or session).
# Priority: running > error > waiting > idle

target="$1"
[ -z "$target" ] && exit 0

has_idle=false
has_waiting=false
has_error=false

while IFS= read -r status; do
    case "$status" in
        running)
            echo "running"
            exit 0
            ;;
        error) has_error=true ;;
        waiting|notification) has_waiting=true ;;
        idle) has_idle=true ;;
    esac
done < <(tmux list-panes -t "$target" -F '#{@pane_status}' 2>/dev/null)

if $has_error; then
    echo "error"
elif $has_waiting; then
    echo "waiting"
elif $has_idle; then
    echo "idle"
fi
