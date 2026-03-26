#!/bin/bash
session="popup_$(basename "$1")"
if tmux has-session -t "$session" 2>/dev/null; then
    echo "Popup"
fi
