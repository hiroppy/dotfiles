#!/usr/bin/env bash
# Personal notification hook for coding agents.
# Register separately in settings.json alongside hook.sh.

set -euo pipefail

agent="${1:-}"
event="${2:-}"

{ [ -z "$agent" ] || [ -z "$event" ]; } && exit 0

input=""
if ! [ -t 0 ]; then
  input="$(cat)"
fi

case "$agent" in
  claude) title="Claude Code" ;;
  codex)  title="Codex" ;;
  *)      exit 0 ;;
esac

notify() {
  local message="$1"
  local sound="${2:-Hero}"
  if command -v fish >/dev/null 2>&1; then
    fish -c "notify -t \"$title\" -s \"$sound\" \"$message\"" >/dev/null 2>&1 || true
  fi
}

case "$event" in
  notification)
    notify "許可を求めています" "Glass"
    ;;
  stop)
    notify "タスクが完了しました"
    ;;
esac
