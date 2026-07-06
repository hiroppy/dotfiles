#!/bin/bash

set -euo pipefail

current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
current_path="$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || true)"

[ -z "$current_window" ] && exit 0
[ -z "$current_pane" ] && exit 0

sidebar_pane=""
current_is_sidebar=false

while IFS='|' read -r pane_id pane_role; do
    [ -z "$pane_id" ] && continue

    if [ -n "$pane_role" ]; then
        sidebar_pane="$pane_id"
        if [ "$pane_id" = "$current_pane" ]; then
            current_is_sidebar=true
        fi
    fi
done < <(tmux list-panes -t "$current_window" -F '#{pane_id}|#{@pane_role}' 2>/dev/null || true)

if [ -z "$sidebar_pane" ]; then
    sidebar_bin="$(tmux display-message -p '#{@agent_sidebar_bin}' 2>/dev/null || true)"
    if [ -z "$sidebar_bin" ]; then
        if [ -x "$HOME/.tmux/plugins/tmux-agent-sidebar/bin/tmux-agent-sidebar" ]; then
            sidebar_bin="$HOME/.tmux/plugins/tmux-agent-sidebar/bin/tmux-agent-sidebar"
        elif [ -x "$HOME/.tmux/plugins/tmux-agent-sidebar/target/release/tmux-agent-sidebar" ]; then
            sidebar_bin="$HOME/.tmux/plugins/tmux-agent-sidebar/target/release/tmux-agent-sidebar"
        else
            exit 1
        fi
    fi

    "$sidebar_bin" toggle "$current_window" "${current_path:-$HOME}"
    exit 0
fi

if [ "$current_is_sidebar" = true ]; then
    # In sidebar -> go to last active pane
    tmux last-pane 2>/dev/null || true
else
    # In main -> go to sidebar
    tmux select-pane -t "$sidebar_pane" 2>/dev/null || true
fi
