#!/usr/bin/env bash

set -euo pipefail

agent="${1:-}"
event="${2:-}"

if [ -z "$agent" ] || [ -z "$event" ]; then
  exit 0
fi

case "$agent" in
  claude)
    title="Claude Code"
    ;;
  codex)
    title="Codex"
    ;;
  *)
    exit 0
    ;;
esac

notify() {
  local message="$1"
  local sound="${2:-Hero}"

  if command -v fish >/dev/null 2>&1; then
    fish -c "notify -t \"$title\" -s \"$sound\" \"$message\"" >/dev/null 2>&1 || true
  fi
}

set_status() {
  local status="$1"
  bash ~/.config/tmux/agent-status.sh "$status"
}

case "$event" in
  notification)
    notify "許可を求めています" "Glass"
    ;;
  stop)
    if [ "$agent" = "claude" ]; then
      notify "タスクが完了しました"
    fi
    set_status "idle"
    ;;
  user-prompt-submit)
    set_status "running"
    ;;
  session-start)
    set_status "idle"
    ;;
  session-end)
    set_status "clear"
    ;;
  *)
    exit 0
    ;;
esac

if [ "$agent" = "codex" ] && [ "$event" = "stop" ]; then
  printf '%s\n' '{"continue":true}'
fi
