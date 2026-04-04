#!/usr/bin/env bash

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$(tmux show -gqv @agent_sidebar_dir 2>/dev/null)" ]; then
    tmux set -g @agent_sidebar_dir "$PLUGIN_DIR"
fi

tmux source-file "$PLUGIN_DIR/agent-sidebar.conf"
