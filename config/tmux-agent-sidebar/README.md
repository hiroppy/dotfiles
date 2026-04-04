# tmux-agent-sidebar

A tmux sidebar dashboard for AI coding agents (Claude Code, Codex).

Displays agent pane statuses with color-coded indicators, user prompts, elapsed time, and a real-time activity log of tool operations in a navigable sidebar UI.

<!-- TODO: screenshot -->

## Features

- Multi-session, multi-agent monitoring at a glance
- Color-coded status icons (running / waiting / idle / error)
- User prompt and agent response display
- Elapsed time tracking per agent
- Git branch and diff stats
- Subagent tree and task progress (Claude Code)
- Real-time activity log of tool operations (Claude Code)
- Permission mode badges
- Fully customizable colors and layout

### Feature Support by Agent

| Feature | Claude Code | Codex | Notes |
|---|---|---|---|
| Status tracking (running / idle / error) | :white_check_mark: | :white_check_mark: | Driven by `SessionStart` / `UserPromptSubmit` / `Stop` |
| Prompt text display | :white_check_mark: | :white_check_mark: | Saved from `UserPromptSubmit` |
| Response text display (`▶ ...`) | :white_check_mark: | :white_check_mark: | Populated from `Stop` payload |
| Waiting status + wait reason | :white_check_mark: | :x: | Codex has no `Notification` hook |
| API failure reason display | :white_check_mark: | :x: | `StopFailure` is wired only for Claude |
| Permission badge | :white_check_mark: (`plan` / `edit` / `auto` / `!`) | :white_check_mark: (`auto` / `!` only) | Codex badges are inferred from process args |
| Git branch display | :white_check_mark: | :white_check_mark: | Uses the pane `cwd` |
| Elapsed time | :white_check_mark: | :white_check_mark: | Since the last prompt |
| Task progress | :white_check_mark: | :x: | Requires `PostToolUse` |
| Subagent display | :white_check_mark: | :x: | Requires `SubagentStart` / `SubagentStop` |
| Activity log | :white_check_mark: | :x: | Requires `PostToolUse` |

## Requirements

- tmux 3.2+
- Bash 4+
- [jq](https://jqlang.github.io/jq/)

## Installation

### TPM (recommended)

Add the plugin to your `tmux.conf`:

```tmux
set -g @plugin 'hiroppy/tmux-agent-sidebar'
run '~/.tmux/plugins/tpm/tpm'
```

### Manual

Clone or symlink to `~/.config/tmux-agent-sidebar/`:

```sh
ln -sfnv ~/path/to/tmux-agent-sidebar ~/.config/tmux-agent-sidebar
```

Then source the config in your `tmux.conf`:

```tmux
source-file ~/.config/tmux-agent-sidebar/agent-sidebar.conf
```

Reload tmux config with `prefix + r`.

## Setting Up Agent Hooks

The sidebar receives status updates through agent hooks. Add the following hook configurations to your agent settings.

<details>
<summary>Claude Code</summary>

Add to your Claude Code hooks configuration (e.g. `~/.claude/settings.json`):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh claude notification"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh claude stop"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh claude stop-failure"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh claude user-prompt-submit"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh claude session-start"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/activity-log.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh claude session-end"
          }
        ]
      }
    ]
  }
}
```

</details>

<details>
<summary>Codex</summary>

Create or edit `~/.codex/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh codex session-start"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh codex user-prompt-submit"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.config/tmux-agent-sidebar/hook.sh codex stop"
          }
        ]
      }
    ]
  }
}
```

> **Note:** Codex does not support `Notification` or `PostToolUse` hooks, so waiting status and activity logging are unavailable.

</details>

## Usage

### Toggle Sidebar

| Key | Action |
|---|---|
| `prefix + e` | Toggle sidebar (default keybinding) |

### Sidebar Navigation

| Key | Action |
|---|---|
| `j` / `Down` | Move selection down |
| `k` / `Up` | Move selection up |
| `l` / `Enter` | Activate selected pane |
| `Tab` | Switch bottom panel tab (Activity / Git) |
| `Esc` | Return focus to agents panel |
| `q` / `Ctrl+c` | Close sidebar |

### Status Icons

| Icon | State | Description |
|---|---|---|
| `●` | Running | Agent is actively processing (pulsing animation) |
| `◐` | Waiting | Agent needs user attention (e.g. permission approval) |
| `○` | Idle | Agent is ready and waiting for input |
| `✕` | Error | Agent encountered an error |

### Permission Badges

Badges appear next to the agent name to indicate the permission mode:

| Badge | Meaning |
|---|---|
| (none) | Normal mode |
| `!` | Full auto mode |
| `!!` | Bypass all mode |

### Sidebar Layout

```
╭ dotfiles ────────────────────╮
│ ● claude            2m35s│
│   feature/new-ui             │
│   ├ Explore                  │
│   └ Plan                     │
│   テストを実行して           │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
│ ○ codex                      │
│   main                       │
│   Waiting for prompt…        │
╰──────────────────────────────╯

╭ Activity │ Git ──────────────╮
│ 22:10                   Edit │
│   sidebar.sh                 │
│ 22:09                   Bash │
│   npm test                   │
│ 22:08                   Read │
│   package.json               │
╰──────────────────────────────╯
```

**Agents panel** shows per-agent: status icon, agent name, elapsed time, git branch, subagents, task progress, and the last user prompt.

**Bottom panel** has two tabs:

- **Activity** — Real-time tool operations (Read, Edit, Bash, etc.)
- **Git** — Branch info, diff stats, and working tree status

### Status Query

You can query the aggregated status of agents in a target (pane, window, or session) programmatically:

```sh
bash ~/.config/tmux-agent-sidebar/check-agent-status.sh <target>
# Returns: running | error | waiting | idle
```

This is useful for integrating agent status into your tmux status bar or scripts.

## Customization

All options can be set **before** `source-file` in your `tmux.conf`:

```tmux
# Sidebar
set -g @sidebar_key T                    # keybinding (default: e)
set -g @sidebar_width 32                 # width in columns or % (default: 15%)

# Colors (256-color palette numbers)
set -g @sidebar_color_running 82         # running icon (default: green)
set -g @sidebar_color_waiting 221        # waiting icon (default: yellow)
set -g @sidebar_color_idle 250           # idle icon (default: light gray)
set -g @sidebar_color_error 203          # error icon (default: red)
set -g @sidebar_color_border 240         # box border (default: dark gray)
set -g @sidebar_color_border_active 117  # active group border (default: cyan)
set -g @sidebar_color_session 39         # session name (default: blue)
set -g @sidebar_color_agent_claude 174   # Claude brand color (default: terracotta)
set -g @sidebar_color_agent_codex 141    # Codex brand color (default: purple)
set -g @sidebar_color_text_active 255    # text for running/waiting (default: white)
set -g @sidebar_color_text_muted 250     # text for idle (default: light gray)
set -g @sidebar_color_wait_reason 221    # wait reason text (default: yellow)
set -g @sidebar_color_path 255           # directory path (default: white)
set -g @sidebar_color_selection 239      # selected row background (default: dark gray)
set -g @sidebar_color_branch 109        # git branch name (default: teal)
set -g @sidebar_prompt_lines 3           # max prompt display lines (default: 3)
set -g @sidebar_activity_lines 8         # max activity log entries (default: 8)

source-file ~/.config/tmux-agent-sidebar/agent-sidebar.conf
```

## Known Limitations

- **Waiting status persists after tool approval (Claude Code)** — After approving a permission prompt, the status stays `waiting` until the next event. This is a limitation of the Claude Code hook system.
- **No waiting status for Codex** — Codex does not support the `Notification` hook, so the `waiting` state is unavailable.

## Uninstalling

1. Remove the `source-file` line (or `set -g @plugin` line) from your `tmux.conf`
2. Remove hook entries from your Claude Code / Codex settings
3. Remove the config directory: `rm -rf ~/.config/tmux-agent-sidebar`
