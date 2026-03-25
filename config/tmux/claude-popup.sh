#!/bin/bash
session="claude-$(basename "$1")"
current_session="$2"

if [ "$current_session" = "$session" ]; then
    tmux detach-client
elif tmux has-session -t "$session" 2>/dev/null; then
    tmux display-popup -w 80% -h 80% -E "tmux attach-session -t '$session'"
else
    tmux display-popup -w 80% -h 80% -d "$1" -E "tmux new-session -s '$session' 'claude --dangerously-skip-permissions'"
fi
