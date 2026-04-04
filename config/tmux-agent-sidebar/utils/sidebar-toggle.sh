#!/bin/bash

set -euo pipefail

create_only=false
if [ "${1:-}" = "--create-only" ]; then
    create_only=true
    shift
fi

window_id="${1:-}"
pane_path="${2:-$HOME}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

[ -z "$window_id" ] && exit 0

sidebar_width_setting="$(tmux display-message -p '#{@sidebar_width}' 2>/dev/null || true)"
[ -z "$sidebar_width_setting" ] && sidebar_width_setting=30

if [[ "$sidebar_width_setting" == *% ]]; then
    window_width="$(tmux display-message -t "$window_id" -p '#{window_width}' 2>/dev/null || true)"
    sidebar_width_percent="${sidebar_width_setting%%%}"

    if [[ "$window_width" =~ ^[0-9]+$ ]] && [[ "$sidebar_width_percent" =~ ^[0-9]+$ ]]; then
        sidebar_width=$(( window_width * sidebar_width_percent / 100 ))
        [ "$sidebar_width" -lt 1 ] && sidebar_width=1
    else
        sidebar_width="$sidebar_width_setting"
    fi
else
    sidebar_width="$sidebar_width_setting"
fi

existing_sidebar="$(
    tmux list-panes -t "$window_id" -F '#{pane_id}|#{@pane_role}' 2>/dev/null \
        | awk -F '|' '$2 == "sidebar" { print $1; exit }'
)"

if [ -n "$existing_sidebar" ]; then
    # In create-only mode, just exit if sidebar already exists
    if "$create_only"; then
        exit 0
    fi
    tmux kill-pane -t "$existing_sidebar"
    exit 0
fi

# Find the leftmost pane in the window so the sidebar always appears at the far left
leftmost_pane="$(
    tmux list-panes -t "$window_id" -F '#{pane_left} #{pane_id}' 2>/dev/null \
        | sort -n | head -1 | awk '{print $2}'
)"
[ -z "$leftmost_pane" ] && leftmost_pane="$window_id"

# Remember the currently focused pane to restore focus after split
active_pane="$(tmux display-message -t "$window_id" -p '#{pane_id}' 2>/dev/null || true)"

# Resolve symlinks so relative path works from dotfiles repo
real_script_dir="$(cd "$script_dir" && pwd -P)"
rust_project="$real_script_dir/.."
rust_bin="$rust_project/target/release/tmux-agent-sidebar"
if [ ! -x "$rust_bin" ]; then
    if [ -f "$rust_project/Cargo.toml" ]; then
        tmux display-message "Building tmux-agent-sidebar..."
        if ! cargo build --release --manifest-path "$rust_project/Cargo.toml" 2>/tmp/tmux-sidebar-build.log; then
            tmux display-message "Build failed. See /tmp/tmux-sidebar-build.log"
            exit 1
        fi
    else
        tmux display-message "tmux-agent-sidebar: Cargo.toml not found"
        exit 1
    fi
fi
sidebar_cmd="$rust_bin"

sidebar_pane="$(
    tmux split-window -h -b -l "$sidebar_width" -t "$leftmost_pane" -c "$pane_path" -P -F '#{pane_id}' \
        "$sidebar_cmd"
)"

tmux set -t "$sidebar_pane" -p @pane_role sidebar 2>/dev/null || true
# Restore focus to the previously active pane
if [ -n "$active_pane" ]; then
    tmux select-pane -t "$active_pane" 2>/dev/null || true
else
    tmux select-pane -t "$window_id" -l 2>/dev/null || true
fi
