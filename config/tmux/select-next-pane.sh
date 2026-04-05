#!/bin/bash

set -euo pipefail

current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"

[ -z "$current_window" ] && exit 0
[ -z "$current_pane" ] && exit 0

panes=()
current_index=-1
current_is_sidebar=false

while IFS='|' read -r pane_id pane_role; do
    [ -z "$pane_id" ] && continue

    if [ "$pane_id" = "$current_pane" ]; then
        if [ -n "$pane_role" ]; then
            current_is_sidebar=true
        fi
        current_index="${#panes[@]}"
    fi

    # Skip sidebar panes from cycling targets
    if [ -n "$pane_role" ]; then
        continue
    fi

    panes+=("$pane_id")
done < <(tmux list-panes -t "$current_window" -F '#{pane_id}|#{@pane_role}' 2>/dev/null || true)

# If currently in sidebar, jump to the first non-sidebar pane
if [ "$current_is_sidebar" = true ]; then
    if [ "${#panes[@]}" -gt 0 ]; then
        tmux select-pane -t "${panes[0]}" 2>/dev/null || true
    fi
    exit 0
fi

if [ "${#panes[@]}" -le 1 ]; then
    exit 0
fi

next_index=$((current_index + 1))
[ "$current_index" -lt 0 ] && next_index=0
[ "$next_index" -ge "${#panes[@]}" ] && next_index=0

tmux select-pane -t "${panes[$next_index]}" 2>/dev/null || true
