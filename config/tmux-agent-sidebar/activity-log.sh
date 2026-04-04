#!/usr/bin/env bash

# PostToolUse hook script for Claude Code
# Appends tool usage to a pane-specific log file for sidebar display.
# Called via settings.json hooks with JSON context on stdin.

set -euo pipefail

[ -z "${TMUX_PANE:-}" ] && exit 0

input=""
if ! [ -t 0 ]; then
  input="$(cat)"
fi

tool_name="$(jq -r '.tool_name // empty' <<< "$input" 2>/dev/null || true)"
[ -z "$tool_name" ] && exit 0

tool_input="$(jq -r '.tool_input // empty' <<< "$input" 2>/dev/null || true)"
tool_response="$(jq -r '.tool_response // empty' <<< "$input" 2>/dev/null || true)"

# Extract a short label from tool_input
label=""
case "$tool_name" in
  Read|Edit|Write)
    label="$(jq -r '.file_path // empty' <<< "$tool_input" 2>/dev/null || true)"
    [ -n "$label" ] && label="$(basename "$label")"
    ;;
  Bash)
    label="$(jq -r '.command // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  Glob)
    label="$(jq -r '.pattern // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  Grep)
    label="$(jq -r '.pattern // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  Agent)
    label="$(jq -r '.description // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  WebFetch)
    label="$(jq -r '.url // empty' <<< "$tool_input" 2>/dev/null || true)"
    # Strip protocol prefix to save space
    label="${label#https://}"
    label="${label#http://}"
    ;;
  WebSearch)
    label="$(jq -r '.query // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  Skill)
    label="$(jq -r '.skill // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  ToolSearch)
    label="$(jq -r '.query // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  TaskCreate)
    task_id="$(jq -r '.task.id // empty' <<< "$tool_response" 2>/dev/null || true)"
    subject="$(jq -r '.subject // empty' <<< "$tool_input" 2>/dev/null || true)"
    if [ -n "$task_id" ]; then
      label="#${task_id} ${subject}"
    else
      label="$subject"
    fi
    ;;
  TaskUpdate)
    label="$(jq -r '[(if .status then .status else empty end), (if .taskId then "#" + .taskId else empty end)] | join(" ")' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  TaskGet|TaskStop|TaskOutput)
    label="$(jq -r '.taskId // .task_id // empty' <<< "$tool_input" 2>/dev/null || true)"
    [ -n "$label" ] && label="#${label}"
    ;;
  SendMessage)
    label="$(jq -r '.to // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  TeamCreate)
    label="$(jq -r '.team_name // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  NotebookEdit)
    label="$(jq -r '.notebook_path // empty' <<< "$tool_input" 2>/dev/null || true)"
    [ -n "$label" ] && label="$(basename "$label")"
    ;;
  LSP)
    label="$(jq -r '.operation // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  AskUserQuestion)
    label="$(jq -r '.questions[0].question // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  CronCreate)
    label="$(jq -r '.cron // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  CronDelete)
    label="$(jq -r '.id // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  EnterWorktree)
    label="$(jq -r '.name // empty' <<< "$tool_input" 2>/dev/null || true)"
    ;;
  *)
    label=""
    ;;
esac

log_file="/tmp/tmux-agent-activity${TMUX_PANE//%/_}.log"

# Sanitize: collapse newlines and pipes to spaces (they break the log format)
label="${label//$'\n'/ }"
label="${label//|/ }"

# Append: timestamp|tool_name|label
printf '%s|%s|%s\n' "$(date +%H:%M)" "$tool_name" "$label" >> "$log_file"

# Keep only the last 50 lines to prevent unbounded growth
if [ -f "$log_file" ]; then
  tail -50 "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
fi
