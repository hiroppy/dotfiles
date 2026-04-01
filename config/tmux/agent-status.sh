#!/bin/bash
# Usage: agent-status.sh <running|idle|clear>

status="$1"
[ -z "$status" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

if [ "$status" = "clear" ]; then
    tmux set -t "$TMUX_PANE" -p -u @pane_status 2>/dev/null
else
    tmux set -t "$TMUX_PANE" -p @pane_status "$status" 2>/dev/null
fi
