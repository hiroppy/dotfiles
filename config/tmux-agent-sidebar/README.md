# tmux-agent-sidebar

tmux sidebar dashboard for AI coding agents (Claude Code, Codex).

Displays agent pane statuses with color-coded indicators, user prompts, elapsed time, and a real-time activity log of tool operations in a navigable sidebar UI.

## Requirements

- tmux 3.2+
- bash 4+
- jq (for reading hook JSON from stdin)
- [bats-core](https://github.com/bats-core/bats-core) (for running tests)

## Setup

### 1. TPM

Add the plugin to `tmux.conf`:

```tmux
set -g @plugin 'your-github-user/tmux-agent-sidebar'
run '~/.tmux/plugins/tpm/tpm'
```

The TPM entrypoint is `tmux-agent-sidebar.tmux`, which loads the shared config from `agent-sidebar.conf` and resolves the bundled scripts automatically.

### 2. Manual install

If you are not using TPM, clone or symlink to `~/.config/tmux-agent-sidebar/`:

```sh
ln -sfnv ~/dotfiles/config/tmux-agent-sidebar ~/.config/tmux-agent-sidebar
```

Then source the config in `tmux.conf`:

```tmux
source-file ~/.config/tmux-agent-sidebar/agent-sidebar.conf
```

This registers the keybinding and sets default options. Reload with `prefix + r`.

### 3. Configure agent hooks

<details>
<summary>Claude Code</summary>

Minimum hooks:

- `SessionStart` - initialize the pane state
- `UserPromptSubmit` - show the last prompt and mark the agent running
- `Stop` - clear running state and save the final summary
- `Notification` - show waiting state and wait reason
- `PostToolUse` - populate the activity log

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

Minimum hooks:

- `SessionStart` - initialize the pane state
- `UserPromptSubmit` - show the last prompt and mark the agent running
- `Stop` - clear running state and save the final summary

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

</details>

Codex does not support a `SessionEnd` hook, so pane cleanup has to happen through `Stop` or an external wrapper.

## Usage

### Keybinding

| Key | Action |
|---|---|
| `prefix + @sidebar_key` | Toggle sidebar (default: `e`) |

### Sidebar navigation

| Key | Action |
|---|---|
| `j` / `↓` | Move selection down (agents panel → bottom panel) |
| `k` / `↑` | Move selection up (bottom panel → agents panel) |
| `l` / `Enter` | Activate selected pane |
| `Tab` | Switch bottom panel tab (Activity ↔ Git) |
| `Esc` | Return focus to agents panel |
| `q` / `Ctrl+c` | Close sidebar |

### Sidebar display

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
╭ project ─────────────────────╮
│ ◐ claude!               45s│
│   develop                    │
│   permission required        │
│   fix the bug                │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
│ ✕ codex!!            3h45m│
│   main                       │
│   ❯ Error: build failed      │
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

#### Agent status examples

Each status icon represents the agent's current state:

**Idle** — Agent is ready and waiting for input

```
╭ project ─────────────────╮
│ ○ claude                 │
│   Waiting for prompt…    │
╰──────────────────────────╯
```

**Running** — Agent is actively processing (icon pulses with color animation)

```
╭ project ─────────────────╮
│ ● claude                 │
│   fix the bug            │
╰──────────────────────────╯
```

**Waiting** — Agent needs user attention (e.g. permission approval)

```
╭ project ─────────────────╮
│ ◐ claude                 │
│   permission required    │
╰──────────────────────────╯
```

**Error** — Agent encountered an error

```
╭ project ─────────────────╮
│ ✕ claude                 │
│   something broke        │
╰──────────────────────────╯
```

#### Subagents & task progress

Running subagents are shown in a tree structure below the parent agent. Task progress is displayed with checkmark icons:

```
│ ● claude                             │
│   ✔◼◻ 1/3                           │
│   ├ Explore #1                       │
│   ├ Plan                             │
│   └ Explore #2                       │
```

#### Bottom panel

The bottom panel has two tabs switchable with `Tab`:

**Activity tab** — Recent tool operations (Claude Code only)

```
╭ Activity │ Git ──────────╮
│10:32                 Edit│
│  src/main.rs             │
│10:31                 Bash│
│  cargo build             │
│10:30                 Read│
│  Cargo.toml              │
╰──────────────────────────╯
```

**Git tab** — Repository status, diff stats, and branch info

```
╭ Activity │ Git ──────────╮
│                    +42-15│
│ feature/sidebar ↑2 ↓1    │
│ Modified: 2              │
│ Untracked: 1             │
╰──────────────────────────╯
```

When there are no changes or activity, a centered placeholder is shown:

```
╭ Activity │ Git ──────────╮
│    Working tree clean    │
╰──────────────────────────╯
```

#### Agent row structure

Each agent row is composed of the following lines (all optional except the status line):

```
│ {icon} {agent}{badge}  {elapsed}│   ← status line
│   {branch}                      │   ← git branch
│   ✔✔◼◻◻ 2/5                    │   ← task progress
│   ├ {subagent}                  │   ← subagents (tree)
│   └ {subagent}                  │
│   {wait reason}                 │   ← wait reason (red)
│   {prompt text}                 │   ← user prompt (max 3 lines)
│   ❯ {response text}            │   ← agent response
```

#### Elements

| Element | Description |
|---|---|
| Session name | Shown only when 2+ sessions exist |
| `╭ dotfiles ───╮` | Repository group name in rounded top border |
| `●` / `◐` / `○` / `✕` / `·` | Status icon: running (pulsing) / waiting / idle / error / unknown |
| `claude` / `codex` | Agent type — **bold** when it is the active pane |
| `!` / `!!` | Permission badge: `!` = FullAuto (yellow), `!!` = BypassAll (red) |
| `2m35s` | Elapsed time since last prompt (right-aligned) |
| `feature/new-ui` | Git branch name (colored, truncated to fit) |
| `✔◼◻` | Task progress — ✔ completed, ◼ in progress, ◻ pending (with count) |
| `├` / `└` | Subagent tree — running subagents listed in tree structure |
| `permission required` | Wait reason (shown in red when waiting) |
| Indented text | User's last prompt (word-wrapped, max 3 lines) |
| `❯` | Agent response prefix (green, char-wrapped) |
| `Waiting for prompt…` | Idle hint when no prompt is set |
| `─ ─ ─` | Separator between agents in the same group |
| Activity box | Recent tool operations for the focused agent (pinned to bottom) |

#### Visual states

| State | Border | Icon color | Elapsed color |
|---|---|---|---|
| Focused group | `@sidebar_color_border_active` | — | — |
| Inactive group | `@sidebar_color_border` (muted) | — | — |
| Running | — | Green (pulsing animation) | Bright white |
| Waiting | — | Yellow | Bright white |
| Idle | — | Gray | Muted |
| Error | — | Red | Muted |
| Selected row | Dark background highlight | — | — |

## Customization

All options can be set **before** `source-file` to override defaults:

```tmux
# Sidebar
set -g @sidebar_key T                    # keybinding (default: e)
set -g @sidebar_width 32                 # width in columns or percentage of window width (default: 15%)

# Colors (256-color palette numbers)
set -g @sidebar_color_session 39         # session name (default: blue)
set -g @sidebar_color_path 255           # directory path (default: white)
set -g @sidebar_color_running 82         # running icon (default: green)
set -g @sidebar_color_waiting 221        # waiting icon (default: yellow)
set -g @sidebar_color_idle 244           # idle icon (default: gray)
set -g @sidebar_color_error 203          # error icon (default: red)
set -g @sidebar_color_border 240         # box border (default: dark gray)
set -g @sidebar_color_text_active 255    # text for running/waiting (default: white)
set -g @sidebar_color_text_muted 250     # text for idle (default: light gray)
set -g @sidebar_color_wait_reason 203    # wait reason text (default: red)
set -g @sidebar_color_agent_claude 174   # Claude brand color (default: terracotta)
set -g @sidebar_color_agent_codex 141    # Codex brand color (default: purple)
set -g @sidebar_color_border_active 117  # active window border (default: cyan)
set -g @sidebar_prompt_lines 3           # max prompt display lines (default: 3)
set -g @sidebar_activity_lines 8        # max activity log entries (default: 8)

source-file ~/.config/tmux-agent-sidebar/agent-sidebar.conf
```

## Status Query Interface

### `check-agent-status.sh <target>`

Query the aggregated status of all agent panes in a target (pane ID, window ID, or session name).

Returns one of: `running`, `error`, `waiting`, `idle`, or empty string.

Priority: `running` > `error` > `waiting` > `idle`

## Hook Events

| Event | Status | Elapsed | Prompt | Wait Reason | Attention |
|---|---|---|---|---|---|
| `user-prompt-submit` | `running` | starts | saved | cleared | cleared |
| `notification` | `waiting` | — | — | saved | set |
| `stop` | `idle` | cleared | — | cleared | cleared |
| `session-start` | `idle` | — | — | — | cleared |
| `session-end` | cleared | cleared | cleared | cleared | cleared |

### Activity Log (Claude Code only)

| Event | Script | Description |
|---|---|---|
| `PostToolUse` | `activity-log.sh` | Appends tool name and target to per-pane log file |

The activity log captures Read, Edit, Write, Bash, Glob, Grep, and Agent tool operations. Log files are stored at `/tmp/tmux-agent-activity_<pane_id>.log` and cleaned up on `session-end`. Codex does not support `PostToolUse` hooks, so activity logging is Claude Code only.

## Pane Attributes

The plugin manages these tmux pane options:

| Attribute | Values | Description |
|---|---|---|
| `@pane_status` | `running` / `waiting` / `idle` / `error` | Agent status |
| `@pane_agent` | `claude` / `codex` | Agent type |
| `@pane_attention` | `notification` / (unset) | Needs user attention |
| `@pane_prompt` | text / (unset) | User's last prompt |
| `@pane_started_at` | epoch seconds / (unset) | When last prompt was submitted |
| `@pane_wait_reason` | `permission_prompt` / `idle_prompt` / ... / (unset) | Why the agent is waiting |
| `@pane_role` | `sidebar` / (unset) | Marks sidebar panes |

## Known Issues

### Claude Code

- **Waiting status persists after tool approval** — When Claude requests tool permission (`Notification` hook), the status changes to `waiting`. After the user approves, Claude resumes processing but there is no hook to signal the transition back to `running`. The status remains `waiting` until the next `Stop` or `UserPromptSubmit` event. This is a limitation of the Claude Code hook system (no "resumed after notification" hook).

### Codex

- **No `Notification` hook** — Codex does not support the `Notification` hook event. The `waiting` status and wait reason display are not available for Codex agents. Only `running` / `idle` states are tracked.
- **Partial permission-mode support** — The sidebar can still show `auto` / `!` badges for Codex when the process is launched with `--full-auto`, `--yolo`, or `--dangerously-bypass-approvals-and-sandbox`. Claude-only `plan` / `edit` badges come from Claude hook data.

### Feature support by agent

| Feature | Claude Code | Codex | Notes |
|---|---|---|---|
| Status tracking (running/idle/error) | ✔ | ✔ | Driven by `SessionStart` / `UserPromptSubmit` / `Stop` |
| Prompt text display | ✔ | ✔ | Saved from `UserPromptSubmit` |
| Response text display (`❯ ...`) | ✔ | ✔ | Populated from `Stop` payload (`last_assistant_message`) |
| Waiting status + wait reason | ✔ | ✘ | Codex has no `Notification` hook |
| API failure reason display | ✔ | ✘ | `StopFailure` is wired only for Claude |
| Permission badge | ✔ (`plan` / `edit` / `auto` / `!`) | ✔ (`auto` / `!` only) | Codex badges are inferred from process args |
| Git branch display | ✔ | ✔ | Uses the pane `cwd` |
| Elapsed time | ✔ | ✔ | Since the last prompt |
| Task progress | ✔ | ✘ | Requires `PostToolUse` |
| Subagent display | ✔ | ✘ | Requires `SubagentStart` / `SubagentStop` |
| Activity log | ✔ | ✘ | Requires `PostToolUse` |

## Uninstalling

1. Remove `source-file` line from `tmux.conf`
2. Remove hook entries from Claude/Codex settings
3. Remove the symlink: `rm ~/.config/tmux-agent-sidebar`

## Tests

```sh
# Run all tests (requires bats-core)
bats config/tmux-agent-sidebar/tests/

# Or via Makefile
make test
```
