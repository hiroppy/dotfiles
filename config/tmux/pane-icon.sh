#!/bin/bash
# Usage: pane-icon.sh <pane_id>
# Outputs: tmux-formatted icon string or empty

pane_id="$1"
[ -z "$pane_id" ] && exit 0

status=$(~/.config/tmux/scripts/check-agent-status.sh "$pane_id" 2>/dev/null)
[ -z "$status" ] && exit 0

case "$status" in
    running)  printf '#[fg=#f0c674]  ' ;;
    waiting)  printf '#[fg=#ddaa44]  ' ;;
    error)    printf '#[fg=#cb4b46]  ' ;;
    idle)     printf '#[fg=#7ca5c4]  ' ;;
esac
