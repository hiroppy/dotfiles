#!/bin/bash
# Usage: pane-icon.sh <pane_id>
# Outputs: running / idle / (empty)

pane_id="$1"
[ -z "$pane_id" ] && exit 0

"$(dirname "$0")/check-agent-status.sh" "$pane_id"
