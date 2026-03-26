#!/bin/bash
session="popup_claude-$(basename "$1")"

# ポップアップ内から呼ばれた場合はdetach（ポップアップが閉じる）
if [ "$(tmux display-message -p '#{session_name}')" = "$session" ]; then
    tmux detach-client
elif tmux has-session -t "$session" 2>/dev/null; then
    tmux display-popup -w 80% -h 80% -E "tmux attach-session -t '$session'"
else
    tmux display-popup -w 80% -h 80% -d "$1" -E "tmux new-session -s '$session' 'claude --dangerously-skip-permissions'"
fi
