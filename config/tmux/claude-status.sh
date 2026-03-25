#!/bin/bash
session="claude-$(basename "$1")"
if tmux has-session -t "$session" 2>/dev/null; then
    echo "Claude"
fi
