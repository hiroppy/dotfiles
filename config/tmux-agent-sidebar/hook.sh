#!/usr/bin/env bash
# Thin wrapper: delegates to Rust binary.
# Called by Claude Code / Codex hooks (settings.json).
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd -P)"
BIN="$PLUGIN_DIR/target/release/tmux-agent-sidebar"
if [ ! -x "$BIN" ]; then
  if [ -f "$PLUGIN_DIR/Cargo.toml" ]; then
    cargo build --release --manifest-path "$PLUGIN_DIR/Cargo.toml" 2>/tmp/tmux-sidebar-build.log || exit 0
  else
    exit 0
  fi
fi
exec "$BIN" hook "$@"
