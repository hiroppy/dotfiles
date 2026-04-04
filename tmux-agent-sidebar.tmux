#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$CURRENT_DIR/config/tmux-agent-sidebar"
SCRIPT_DIR="$PLUGIN_DIR/scripts"

if [ -z "$(tmux show -gqv @agent_sidebar_dir 2>/dev/null)" ]; then
    tmux set -g @agent_sidebar_dir "$SCRIPT_DIR"
fi

tmux source-file "$PLUGIN_DIR/agent-sidebar.conf"
