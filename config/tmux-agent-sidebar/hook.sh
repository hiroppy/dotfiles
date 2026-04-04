#!/usr/bin/env bash

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"

agent="${1:-}"
event="${2:-}"

if [ -z "$agent" ] || [ -z "$event" ]; then
  exit 0
fi

# Read JSON from stdin (hooks pass context as JSON)
input=""
if ! [ -t 0 ]; then
  input="$(cat)"
fi

json_field() {
  jq -r ".$1 // empty" <<< "$input" 2>/dev/null || true
}

case "$agent" in
  claude|codex) ;;
  *) exit 0 ;;
esac

set_status() {
  bash "$PLUGIN_DIR/utils/agent-status.sh" "$1" || true
}

set_attention() {
  local state="${1:-clear}"
  [ -z "${TMUX_PANE:-}" ] && return 0
  if [ "$state" = "clear" ]; then
    tmux set -t "$TMUX_PANE" -p -u @pane_attention 2>/dev/null || true
  else
    tmux set -t "$TMUX_PANE" -p @pane_attention "$state" 2>/dev/null || true
  fi
}

set_agent_meta() {
  [ -z "${TMUX_PANE:-}" ] && return 0
  tmux set -t "$TMUX_PANE" -p @pane_agent "$agent" 2>/dev/null || true
  local cwd
  cwd="$(json_field cwd)"
  [ -n "$cwd" ] && tmux set -t "$TMUX_PANE" -p @pane_cwd "$cwd" 2>/dev/null || true
  local pmode
  pmode="$(json_field permission_mode)"
  if [ -n "$pmode" ]; then
    tmux set -t "$TMUX_PANE" -p @pane_permission_mode "$pmode" 2>/dev/null || true
  fi
}

# Clear transient pane state (run data, wait reason)
clear_run_state() {
  [ -z "${TMUX_PANE:-}" ] && return 0
  tmux set -t "$TMUX_PANE" -p -u @pane_started_at 2>/dev/null || true
  tmux set -t "$TMUX_PANE" -p -u @pane_wait_reason 2>/dev/null || true
}

# Clear all pane metadata
clear_all_meta() {
  [ -z "${TMUX_PANE:-}" ] && return 0
  tmux set -t "$TMUX_PANE" -p -u @pane_agent 2>/dev/null || true
  tmux set -t "$TMUX_PANE" -p -u @pane_prompt 2>/dev/null || true
  tmux set -t "$TMUX_PANE" -p -u @pane_subagents 2>/dev/null || true
  tmux set -t "$TMUX_PANE" -p -u @pane_subagents_done 2>/dev/null || true
  tmux set -t "$TMUX_PANE" -p -u @pane_cwd 2>/dev/null || true
  tmux set -t "$TMUX_PANE" -p -u @pane_permission_mode 2>/dev/null || true
  clear_run_state
}

# Join array elements with commas
join_csv() {
  local IFS=','
  echo "$*"
}

# Add a subagent to the running list (with sequential numbering)
add_subagent() {
  [ -z "${TMUX_PANE:-}" ] && return 0
  local agent_type="$1"
  [ -z "$agent_type" ] && return 0
  local current
  current="$(tmux show -t "$TMUX_PANE" -pv @pane_subagents 2>/dev/null || true)"
  # Count existing entries of same type to assign number
  local count=0
  if [ -n "$current" ]; then
    IFS=',' read -ra existing <<< "$current"
    for item in "${existing[@]}"; do
      # Strip " #N" suffix to get base type
      local base="${item%% #*}"
      if [ "$base" = "$agent_type" ]; then
        ((count++))
      fi
    done
  fi
  local label="$agent_type"
  if [ "$count" -gt 0 ]; then
    label="${agent_type} #$((count + 1))"
    # Also rename the first one to #1 if it doesn't have a number yet
    if [ "$count" -eq 1 ]; then
      current="${current//$agent_type/$agent_type #1}"
    fi
  fi
  if [ -z "$current" ]; then
    tmux set -t "$TMUX_PANE" -p @pane_subagents "$label" 2>/dev/null || true
  else
    tmux set -t "$TMUX_PANE" -p @pane_subagents "${current},${label}" 2>/dev/null || true
  fi
}

# Remove a subagent from the running list
remove_subagent() {
  [ -z "${TMUX_PANE:-}" ] && return 0
  local agent_type="$1"
  [ -z "$agent_type" ] && return 0
  local current
  current="$(tmux show -t "$TMUX_PANE" -pv @pane_subagents 2>/dev/null || true)"
  [ -z "$current" ] && return 0
  IFS=',' read -ra items <<< "$current"
  # Find last matching entry to remove
  local last_match_idx=-1
  for i in "${!items[@]}"; do
    local base="${items[$i]%% #*}"
    [ "$base" = "$agent_type" ] && last_match_idx=$i
  done
  [ "$last_match_idx" -eq -1 ] && return 0
  # Build filtered array
  local filtered=()
  for i in "${!items[@]}"; do
    [ "$i" -eq "$last_match_idx" ] && continue
    filtered+=("${items[$i]}")
  done
  # If only one of this type remains, remove its " #1" suffix
  local remaining_count=0
  local remaining_idx=-1
  for i in "${!filtered[@]}"; do
    local base="${filtered[$i]%% #*}"
    if [ "$base" = "$agent_type" ]; then
      ((remaining_count++))
      remaining_idx=$i
    fi
  done
  if [ "$remaining_count" -eq 1 ] && [ "$remaining_idx" -ge 0 ]; then
    filtered[$remaining_idx]="$agent_type"
  fi
  local new_list
  new_list="$(join_csv "${filtered[@]+"${filtered[@]}"}")"
  if [ -z "$new_list" ]; then
    tmux set -t "$TMUX_PANE" -p -u @pane_subagents 2>/dev/null || true
  else
    tmux set -t "$TMUX_PANE" -p @pane_subagents "$new_list" 2>/dev/null || true
  fi
}

case "$event" in
  notification)
    set_agent_meta
    wait_reason="$(json_field notification_type)"
    # idle_prompt is just the normal prompt — treat as idle, not waiting
    if [ "$wait_reason" = "idle_prompt" ]; then
      exit 0
    fi
    set_status "waiting"
    set_attention "notification"
    if [ -n "${TMUX_PANE:-}" ]; then
      [ -n "$wait_reason" ] && tmux set -t "$TMUX_PANE" -p @pane_wait_reason "$wait_reason" 2>/dev/null || true
    fi
    ;;
  stop)
    set_agent_meta
    set_attention "clear"
    if [ -n "${TMUX_PANE:-}" ]; then
      last_msg="$(json_field last_assistant_message)"
      if [ -n "$last_msg" ]; then
        last_msg="${last_msg//$'\n'/ }"
        last_msg="${last_msg//|/ }"
        last_msg="${last_msg:0:200}"
        tmux set -t "$TMUX_PANE" -p @pane_prompt "$(printf '\xe2\x9d\xaf\xc2\xa0')$last_msg" 2>/dev/null || true
      fi
      tmux set -t "$TMUX_PANE" -p -u @pane_subagents 2>/dev/null || true
      tmux set -t "$TMUX_PANE" -p -u @pane_subagents_done 2>/dev/null || true
    fi
    clear_run_state
    set_status "idle"
    ;;
  stop-failure)
    set_agent_meta
    set_attention "clear"
    clear_run_state
    if [ -n "${TMUX_PANE:-}" ]; then
      tmux set -t "$TMUX_PANE" -p -u @pane_subagents 2>/dev/null || true
      tmux set -t "$TMUX_PANE" -p -u @pane_subagents_done 2>/dev/null || true
      error_type="$(json_field error)"
      error_details="$(json_field error_details)"
      reason="$error_type"
      [ -z "$reason" ] && reason="$error_details"

      [ -n "$reason" ] && tmux set -t "$TMUX_PANE" -p @pane_wait_reason "$reason" 2>/dev/null || true
    fi
    set_status "error"
    ;;
  subagent-start)
    [ -n "${TMUX_PANE:-}" ] && add_subagent "$(json_field agent_type)"
    ;;
  subagent-stop)
    # Count completed subagents; clear list when all have finished
    if [ -n "${TMUX_PANE:-}" ]; then
      current="$(tmux show -t "$TMUX_PANE" -pv @pane_subagents 2>/dev/null || true)"
      [ -z "$current" ] && exit 0
      done_count="$(tmux show -t "$TMUX_PANE" -pv @pane_subagents_done 2>/dev/null || true)"
      done_count=$(( ${done_count:-0} + 1 ))
      # Count total subagents in the list
      total=$(echo "$current" | tr ',' '\n' | wc -l | tr -d ' ')
      if [ "$done_count" -ge "$total" ]; then
        tmux set -t "$TMUX_PANE" -p -u @pane_subagents 2>/dev/null || true
        tmux set -t "$TMUX_PANE" -p -u @pane_subagents_done 2>/dev/null || true
      else
        tmux set -t "$TMUX_PANE" -p @pane_subagents_done "$done_count" 2>/dev/null || true
      fi
    fi
    ;;
  user-prompt-submit)
    set_agent_meta
    set_attention "clear"
    set_status "running"
    if [ -n "${TMUX_PANE:-}" ]; then
      prompt="$(json_field prompt)"
      # Skip system-injected messages (task-notification, system-reminder, etc.)
      if [ -n "$prompt" ] && ! [[ "$prompt" == *"<"*">"* ]]; then
        prompt="${prompt//$'\n'/ }"
        prompt="${prompt//|/ }"
        prompt="${prompt:0:200}"
        tmux set -t "$TMUX_PANE" -p @pane_prompt "$prompt" 2>/dev/null || true
      fi
      tmux set -t "$TMUX_PANE" -p @pane_started_at "$(date +%s)" 2>/dev/null || true
      tmux set -t "$TMUX_PANE" -p -u @pane_wait_reason 2>/dev/null || true
    fi
    ;;
  session-start)
    set_agent_meta
    set_attention "clear"
    clear_run_state
    if [ -n "${TMUX_PANE:-}" ]; then
      tmux set -t "$TMUX_PANE" -p -u @pane_prompt 2>/dev/null || true
      tmux set -t "$TMUX_PANE" -p -u @pane_subagents 2>/dev/null || true
      tmux set -t "$TMUX_PANE" -p -u @pane_subagents_done 2>/dev/null || true
    fi
    set_status "idle"
    ;;
  session-end)
    set_attention "clear"
    clear_all_meta
    set_status "clear"
    # Clean up activity log file for this pane
    if [ -n "${TMUX_PANE:-}" ]; then
      rm -f "/tmp/tmux-agent-activity${TMUX_PANE//%/_}.log"
    fi
    ;;
  *)
    exit 0
    ;;
esac

if [ "$agent" = "codex" ] && [ "$event" = "stop" ]; then
  printf '%s\n' '{"continue":true}'
fi
