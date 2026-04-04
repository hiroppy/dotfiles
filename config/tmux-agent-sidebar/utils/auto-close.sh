#!/bin/bash
# Auto-close window when only sidebar panes remain.
# Called from pane-exited hook.

window_id="${1:-}"
[ -z "$window_id" ] && exit 0

# Count non-sidebar panes
non_sidebar=$(tmux list-panes -t "$window_id" -F '#{@pane_role}' 2>/dev/null | grep -cv '^sidebar$' || true)

if [ "$non_sidebar" -eq 0 ]; then
    tmux kill-window -t "$window_id" 2>/dev/null || true
fi
