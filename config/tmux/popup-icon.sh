#!/bin/bash
# Usage: popup-icon.sh <pane_current_path>
# Outputs: tmux-formatted popup icon string or empty
# Background is always orange (#da7756); icon changes by agent status.

session="popup_$(basename "$1")"
tmux has-session -t "$session" 2>/dev/null || exit 0

status=$(~/.config/tmux/scripts/check-agent-status.sh "$session" 2>/dev/null)

case "${status:-popup}" in
    running) icon="" ;;
    waiting) icon="" ;;
    error)   icon="" ;;
    idle)    icon="" ;;
    *)       icon="" ;;
esac

if [ -n "$icon" ]; then
    printf '#[fg=#ffffff]#[bg=#da7756] #[fg=#ffffff]%s  Popup #[fg=#da7756]#[bg=#333333]#[default] ' "$icon"
else
    printf '#[fg=#ffffff]#[bg=#da7756] Popup #[fg=#da7756]#[bg=#333333]#[default] '
fi
