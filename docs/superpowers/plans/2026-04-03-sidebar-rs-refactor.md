# tmux-agent-sidebar-rs リファクタリング Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ui.rsを責務ごとに分割し、マウスクリックのレイアウト重複を解消し、スタイル情報込みスナップショットテストで色デグレを検出可能にする

**Architecture:** ui.rsをui/mod.rs, ui/agents.rs, ui/activity.rs, ui/colors.rs, ui/text.rsに分割。描画時にline_to_rowマッピングをstateに書き込み、main.rsのマウスハンドラはそれを参照するだけにする。テストはratatui TestBackendのBuffer からスタイル情報（fg/modifier）込みの文字列を生成し、instaでスナップショット比較。

**Tech Stack:** Rust, ratatui, crossterm, unicode-width, insta

---

## File Structure

```
src/
├── main.rs              # イベントループ（mouse handlerはstate.line_to_rowを参照するだけに簡素化）
├── lib.rs               # pub mod宣言
├── tmux.rs              # そのまま（#![allow(dead_code)]→個別#[allow]）
├── activity.rs          # そのまま
├── state.rs             # line_to_row: Vec<Option<usize>> 追加、#![allow(dead_code)]削除
└── ui/
    ├── mod.rs           # draw(), activity_box_height()
    ├── agents.rs        # draw_agents(), render_pane_lines()
    ├── activity.rs      # draw_activity()
    ├── colors.rs        # 色定数、status_color(), agent_color()
    └── text.rs          # display_width(), pad_to(), wrap_text(), elapsed_label(), wait_reason_label(), window_title()
tests/
├── ui_snapshot.rs       # スタイル込みスナップショットテスト（既存+新規）
└── snapshots/           # instaスナップショットファイル
```

---

### Task 1: ui/colors.rs — 色定数とヘルパーの抽出

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/ui/colors.rs`

- [ ] **Step 1: ui/colors.rsを作成**

```rust
use ratatui::style::Color;
use crate::tmux::{AgentType, PaneStatus};

// Border colors
pub const BORDER_ACTIVE: Color = Color::Indexed(117);
pub const BORDER_INACTIVE: Color = Color::Indexed(240);

// Status icon colors
pub const STATUS_RUNNING: Color = Color::Indexed(82);
pub const STATUS_WAITING: Color = Color::Indexed(221);
pub const STATUS_IDLE: Color = Color::Indexed(250);
pub const STATUS_ERROR: Color = Color::Indexed(203);
pub const STATUS_UNKNOWN: Color = Color::Indexed(244);

// Agent name colors (idle state)
pub const AGENT_CLAUDE: Color = Color::Indexed(174);
pub const AGENT_CODEX: Color = Color::Indexed(141);

// Text colors
pub const TEXT_ACTIVE: Color = Color::Indexed(255);
pub const TEXT_MUTED: Color = Color::Indexed(244);

// Session header
pub const SESSION_HEADER: Color = Color::Indexed(39);

// Wait reason
pub const WAIT_REASON: Color = Color::Indexed(221);

// Activity border (unfocused)
pub const ACTIVITY_BORDER: Color = Color::Indexed(39);

pub fn status_color(status: &PaneStatus, attention: bool) -> Color {
    if attention {
        return STATUS_WAITING;
    }
    match status {
        PaneStatus::Running => STATUS_RUNNING,
        PaneStatus::Waiting => STATUS_WAITING,
        PaneStatus::Idle => STATUS_IDLE,
        PaneStatus::Error => STATUS_ERROR,
        PaneStatus::Unknown => STATUS_UNKNOWN,
    }
}

pub fn agent_color(agent: &AgentType) -> Color {
    match agent {
        AgentType::Claude => AGENT_CLAUDE,
        AgentType::Codex => AGENT_CODEX,
        AgentType::Unknown => TEXT_MUTED,
    }
}
```

- [ ] **Step 2: ビルド確認（まだmod宣言なし、ファイル作成のみ）**

Run: `cd config/tmux-agent-sidebar-rs && cargo check 2>&1`
Expected: 既存コードは変更なしなので成功

- [ ] **Step 3: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui/colors.rs
git commit -m "refactor: extract color constants and helpers to ui/colors.rs"
```

---

### Task 2: ui/text.rs — テキストヘルパーの抽出

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/ui/text.rs`

- [ ] **Step 1: ui/text.rsを作成**

ui.rsから以下の関数を移動（コピー）:

```rust
use unicode_width::UnicodeWidthStr;
use crate::tmux::WindowInfo;

/// Display width of a string (CJK = 2 columns, ASCII = 1)
pub fn display_width(s: &str) -> usize {
    UnicodeWidthStr::width(s)
}

/// Pad string with spaces to fill `target_width` display columns
pub fn pad_to(current_display_width: usize, target_width: usize) -> String {
    let pad = target_width.saturating_sub(current_display_width);
    " ".repeat(pad)
}

pub fn elapsed_label(started_at: Option<u64>) -> String {
    let ts = match started_at {
        Some(t) if t > 0 => t,
        _ => return String::new(),
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    if now < ts {
        return String::new();
    }
    let elapsed = now - ts;
    let secs = elapsed % 60;
    let mins = (elapsed / 60) % 60;
    let hours = elapsed / 3600;
    if hours > 0 {
        format!("{}h{}m{}s", hours, mins, secs)
    } else if mins > 0 {
        format!("{}m{}s", mins, secs)
    } else {
        format!("{}s", secs)
    }
}

pub fn wait_reason_label(reason: &str) -> String {
    match reason {
        "permission_prompt" => "permission required".into(),
        "idle_prompt" => "waiting for input".into(),
        "auth_success" => "auth success".into(),
        "elicitation_dialog" => "waiting for selection".into(),
        _ => {
            if reason.is_empty() {
                String::new()
            } else {
                reason.to_string()
            }
        }
    }
}

pub fn window_title(window: &WindowInfo) -> String {
    if !window.auto_rename {
        return window.window_name.clone();
    }
    let pane = window
        .panes
        .iter()
        .find(|p| p.pane_active)
        .or(window.panes.first());
    match pane {
        Some(p) => {
            let path = &p.path;
            path.rsplit('/').next().unwrap_or(path).to_string()
        }
        None => window.window_name.clone(),
    }
}

/// Wrap text by display width (not byte count)
pub fn wrap_text(text: &str, max_width: usize, max_lines: usize) -> Vec<String> {
    if max_width == 0 || max_lines == 0 {
        return vec![];
    }

    let chars: Vec<char> = text.chars().collect();
    let mut result: Vec<String> = Vec::new();
    let mut pos = 0;

    while pos < chars.len() && result.len() < max_lines {
        let mut chunk = String::new();
        let mut chunk_width = 0;
        let mut end = pos;

        while end < chars.len() {
            let ch_w = unicode_width::UnicodeWidthChar::width(chars[end]).unwrap_or(0);
            if chunk_width + ch_w > max_width {
                break;
            }
            chunk.push(chars[end]);
            chunk_width += ch_w;
            end += 1;
        }

        if end >= chars.len() {
            result.push(chunk);
            break;
        }

        if result.len() + 1 == max_lines {
            let mut trunc = String::new();
            let mut tw = 0;
            let ellipsis_w = 1;
            for i in pos..chars.len() {
                let ch_w = unicode_width::UnicodeWidthChar::width(chars[i]).unwrap_or(0);
                if tw + ch_w + ellipsis_w > max_width {
                    break;
                }
                trunc.push(chars[i]);
                tw += ch_w;
            }
            trunc.push('…');
            result.push(trunc);
            break;
        }

        if let Some(space_pos) = chunk.rfind(' ') {
            if space_pos > 0 {
                let nice_chunk = chunk[..space_pos].to_string();
                let char_count = nice_chunk.chars().count();
                result.push(nice_chunk);
                pos += char_count;
                while pos < chars.len() && chars[pos] == ' ' {
                    pos += 1;
                }
                continue;
            }
        }

        result.push(chunk);
        pos = end;
    }

    result
}
```

- [ ] **Step 2: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui/text.rs
git commit -m "refactor: extract text helpers to ui/text.rs"
```

---

### Task 3: ui/agents.rs — エージェント描画の抽出

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/ui/agents.rs`

- [ ] **Step 1: ui/agents.rsを作成**

ui.rsのdraw_agents()とrender_pane_lines()を移動。`line_to_row`マッピングをstateに書き込む機能を追加。

```rust
use ratatui::{
    Frame,
    layout::Rect,
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::Paragraph,
};

use crate::state::{AppState, Focus};
use crate::tmux::PaneStatus;

use super::colors;
use super::text::{display_width, elapsed_label, pad_to, wait_reason_label, window_title, wrap_text};

pub fn draw_agents(frame: &mut Frame, state: &mut AppState, area: Rect) {
    let multi_session = state.sessions.len() > 1;
    let mut lines: Vec<Line<'_>> = Vec::new();
    let mut row_index: usize = 0;
    let width = area.width as usize;
    let mut line_to_row: Vec<Option<usize>> = Vec::new();

    for session in &state.sessions {
        if multi_session {
            let header = format!(" {} ", session.session_name);
            lines.push(Line::from(Span::styled(
                header,
                Style::default()
                    .fg(colors::SESSION_HEADER)
                    .add_modifier(Modifier::BOLD),
            )));
            line_to_row.push(None);
        }

        for window in &session.windows {
            if window.panes.is_empty() {
                continue;
            }

            let border_color = if window.window_active {
                colors::BORDER_ACTIVE
            } else {
                colors::BORDER_INACTIVE
            };
            let title = window_title(window);

            let title_dw = display_width(&title);
            let fill_len = width.saturating_sub(3 + title_dw + 1);
            let top_line = format!("╭ {} {}╮", title, "─".repeat(fill_len));
            lines.push(Line::from(Span::styled(
                top_line,
                Style::default().fg(border_color),
            )));
            line_to_row.push(None);

            for (pi, pane) in window.panes.iter().enumerate() {
                if pi > 0 {
                    let gray = Style::default().fg(colors::BORDER_INACTIVE);
                    let dashes = "─".repeat(width.saturating_sub(4));
                    lines.push(Line::from(vec![
                        Span::styled("│", Style::default().fg(border_color)),
                        Span::styled(format!(" {} ", dashes), gray),
                        Span::styled("│", Style::default().fg(border_color)),
                    ]));
                    line_to_row.push(None);
                }

                let is_selected = state.sidebar_focused
                    && state.focus == Focus::Agents
                    && row_index == state.selected_agent_row;

                let is_active = state
                    .focused_pane_id
                    .as_ref()
                    .is_some_and(|id| id == &pane.pane_id);

                let pane_lines =
                    render_pane_lines(pane, is_selected, is_active, border_color, width);
                for _ in &pane_lines {
                    line_to_row.push(Some(row_index));
                }
                lines.extend(pane_lines);

                row_index += 1;
            }

            let bottom_line = format!("╰{}╯", "─".repeat(width.saturating_sub(2)));
            lines.push(Line::from(Span::styled(
                bottom_line,
                Style::default().fg(border_color),
            )));
            line_to_row.push(None);
        }
    }

    state.line_to_row = line_to_row;

    let paragraph = Paragraph::new(lines);
    frame.render_widget(paragraph, area);
}

fn render_pane_lines<'a>(
    pane: &crate::tmux::PaneInfo,
    selected: bool,
    active: bool,
    border_color: ratatui::style::Color,
    width: usize,
) -> Vec<Line<'a>> {
    let mut out: Vec<Line<'a>> = Vec::new();

    let border_style = Style::default().fg(border_color);
    let inner_width = width.saturating_sub(3);

    let icon = pane.status.icon();
    let icon_color = colors::status_color(&pane.status, pane.attention);
    let label = pane.agent.label();
    let elapsed = elapsed_label(pane.started_at);

    let is_active_status = matches!(pane.status, PaneStatus::Running | PaneStatus::Waiting);
    let agent_fg = if is_active_status {
        colors::TEXT_ACTIVE
    } else {
        colors::agent_color(&pane.agent)
    };
    let elapsed_fg = if is_active_status {
        colors::TEXT_ACTIVE
    } else {
        colors::TEXT_MUTED
    };
    let active_mod = if active { Modifier::BOLD } else { Modifier::empty() };

    let left_dw = display_width(icon) + 1 + display_width(label);
    let elapsed_dw = display_width(&elapsed);
    let padding = pad_to(left_dw + elapsed_dw, inner_width);

    if selected {
        let rev = Style::default().add_modifier(Modifier::REVERSED);
        let plain = format!(" {} {}{}{}", icon, label, padding, elapsed);
        let status_line = Line::from(vec![
            Span::styled("│", border_style),
            Span::styled(plain, rev),
            Span::styled("│", border_style),
        ]);
        out.push(status_line);
    } else {
        let name_style = Style::default().fg(agent_fg).add_modifier(active_mod);
        let status_line = Line::from(vec![
            Span::styled("│ ", border_style),
            Span::styled(icon.to_string(), Style::default().fg(icon_color)),
            Span::styled(format!(" {}", label), name_style),
            Span::styled(padding, Style::default()),
            Span::styled(elapsed, Style::default().fg(elapsed_fg)),
            Span::styled("│", border_style),
        ]);
        out.push(status_line);
    }

    if !pane.wait_reason.is_empty() {
        let reason = wait_reason_label(&pane.wait_reason);
        let text = format!("  {}", reason);
        let text_dw = display_width(&text);
        let padding = pad_to(text_dw, inner_width);
        let wait_line = Line::from(vec![
            Span::styled("│ ", border_style),
            Span::styled(text, Style::default().fg(colors::WAIT_REASON)),
            Span::styled(padding, Style::default()),
            Span::styled("│", border_style),
        ]);
        out.push(wait_line);
    }

    if !pane.prompt.is_empty() {
        let prompt_color = if active {
            colors::TEXT_ACTIVE
        } else {
            colors::TEXT_MUTED
        };
        let wrapped = wrap_text(&pane.prompt, inner_width.saturating_sub(2), 3);
        for wl in wrapped {
            let text = format!("  {}", wl);
            let text_dw = display_width(&text);
            let padding = pad_to(text_dw, inner_width);
            let prompt_line = Line::from(vec![
                Span::styled("│ ", border_style),
                Span::styled(text, Style::default().fg(prompt_color)),
                Span::styled(padding, Style::default()),
                Span::styled("│", border_style),
            ]);
            out.push(prompt_line);
        }
    }

    out
}
```

- [ ] **Step 2: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui/agents.rs
git commit -m "refactor: extract agent box rendering to ui/agents.rs with line_to_row"
```

---

### Task 4: ui/activity.rs — Activity描画の抽出

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/ui/activity.rs`

- [ ] **Step 1: ui/activity.rsを作成**

```rust
use ratatui::{
    Frame,
    layout::Rect,
    style::Style,
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
};

use crate::state::{AppState, Focus};

use super::colors;
use super::text::{display_width, pad_to, wrap_text};

pub fn draw_activity(frame: &mut Frame, state: &mut AppState, area: Rect) {
    let border_color = if state.sidebar_focused && state.focus == Focus::ActivityLog {
        colors::BORDER_ACTIVE
    } else {
        colors::ACTIVITY_BORDER
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(ratatui::widgets::BorderType::Rounded)
        .title(" Activity ")
        .style(Style::default().fg(border_color));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    if state.activity_entries.is_empty() {
        return;
    }

    let mut lines: Vec<Line<'_>> = Vec::new();
    let inner_w = inner.width as usize;

    for entry in &state.activity_entries {
        let tool_color = ratatui::style::Color::Indexed(entry.tool_color_index());

        let ts_dw = display_width(&entry.timestamp);
        let tool_dw = display_width(&entry.tool);
        let gap = pad_to(ts_dw + tool_dw, inner_w);
        let line1 = Line::from(vec![
            Span::styled(
                entry.timestamp.clone(),
                Style::default().fg(colors::TEXT_MUTED),
            ),
            Span::raw(gap),
            Span::styled(entry.tool.clone(), Style::default().fg(tool_color)),
        ]);
        lines.push(line1);

        if !entry.label.is_empty() {
            let label_max_w = inner_w.saturating_sub(2);
            let wrapped = wrap_text(&entry.label, label_max_w, 3);
            for wl in wrapped {
                let text = format!("  {}", wl);
                lines.push(Line::from(Span::styled(
                    text,
                    Style::default().fg(colors::TEXT_MUTED),
                )));
            }
        }
    }

    state.activity_total_lines = lines.len();
    state.activity_visible_height = inner.height as usize;

    let scroll_offset = state.activity_scroll_offset as u16;
    let paragraph = Paragraph::new(lines).scroll((scroll_offset, 0));
    frame.render_widget(paragraph, inner);
}
```

- [ ] **Step 2: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui/activity.rs
git commit -m "refactor: extract activity log rendering to ui/activity.rs"
```

---

### Task 5: ui/mod.rs — モジュール配線と旧ui.rs置換

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/ui/mod.rs`
- Delete: `config/tmux-agent-sidebar-rs/src/ui.rs`
- Modify: `config/tmux-agent-sidebar-rs/src/state.rs` (line_to_row追加、#![allow(dead_code)]削除)
- Modify: `config/tmux-agent-sidebar-rs/src/tmux.rs` (#![allow(dead_code)]削除、個別#[allow])
- Modify: `config/tmux-agent-sidebar-rs/src/main.rs` (click_agent_rowをline_to_row参照に簡素化)

- [ ] **Step 1: state.rsにline_to_rowフィールド追加、#![allow(dead_code)]削除**

state.rsの変更:
- 1行目の`#![allow(dead_code)]`を削除
- AppStructに`pub line_to_row: Vec<Option<usize>>`追加
- new()の初期化に`line_to_row: vec![]`追加
- 未使用の`selected_target()`を削除

- [ ] **Step 2: tmux.rsの#![allow(dead_code)]を個別#[allow]に変更**

tmux.rsの変更:
- 1行目の`#![allow(dead_code)]`を削除
- 未使用フィールドのある構造体に`#[allow(dead_code)]`を追加:

```rust
#[derive(Debug, Clone)]
pub struct PaneInfo {
    pub pane_id: String,
    pub pane_active: bool,
    pub status: PaneStatus,
    pub attention: bool,
    pub agent: AgentType,
    #[allow(dead_code)]
    pub pane_name: String,
    pub path: String,
    #[allow(dead_code)]
    pub command: String,
    #[allow(dead_code)]
    pub role: String,
    pub prompt: String,
    pub started_at: Option<u64>,
    pub wait_reason: String,
}
```

WindowInfo, SessionInfo, AgentTypeも同様に個別#[allow]。

- [ ] **Step 3: ui/mod.rsを作成**

```rust
pub mod agents;
pub mod activity;
pub mod colors;
pub mod text;

use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout},
    widgets::Paragraph,
};

use crate::state::AppState;

pub fn draw(frame: &mut Frame, state: &mut AppState) {
    let area = frame.area();

    if state.sessions.is_empty() {
        let msg = Paragraph::new("No agent panes found");
        frame.render_widget(msg, area);
        return;
    }

    let act_h = if state.activity_entries.is_empty() {
        0
    } else {
        activity_box_height(state)
    };

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(if act_h > 0 {
            vec![Constraint::Min(1), Constraint::Length(act_h)]
        } else {
            vec![Constraint::Min(1)]
        })
        .split(area);

    agents::draw_agents(frame, state, chunks[0]);

    if act_h > 0 && chunks.len() > 1 {
        activity::draw_activity(frame, state, chunks[1]);
    }
}

pub fn activity_box_height(state: &AppState) -> u16 {
    let visible = state.activity_entries.len().min(8);
    ((visible * 2 + 2) as u16).min(20)
}
```

- [ ] **Step 4: 旧ui.rsを削除**

```bash
rm config/tmux-agent-sidebar-rs/src/ui.rs
```

- [ ] **Step 5: main.rsのclick_agent_rowをline_to_row参照に簡素化**

main.rsのclick_agent_row関数を以下に置換:

```rust
fn click_agent_row(state: &mut AppState, row: u16) {
    state.focus = Focus::Agents;
    if let Some(Some(agent_idx)) = state.line_to_row.get(row as usize) {
        state.selected_agent_row = *agent_idx;
        state.activate_selection();
    }
}
```

main.rsのhandle_mouse_clickも簡素化（activity領域の判定にline_to_rowの長さを使う）:

```rust
fn handle_mouse_click(state: &mut AppState, row: u16, size: ratatui::layout::Rect) {
    if state.activity_entries.is_empty() {
        click_agent_row(state, row);
        return;
    }

    let activity_height = ui::activity_box_height(state);
    let agent_area_height = size.height.saturating_sub(activity_height);

    if row < agent_area_height {
        click_agent_row(state, row);
    } else {
        state.focus = Focus::ActivityLog;
    }
}
```

- [ ] **Step 6: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功、警告なし

- [ ] **Step 7: 既存テスト実行**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 全テストパス（スナップショットの内容は変更なし）

- [ ] **Step 8: Commit**

```bash
git add -A config/tmux-agent-sidebar-rs/src/
git commit -m "refactor: split ui.rs into ui/ module with colors, text, agents, activity"
```

---

### Task 6: スナップショットテストをスタイル情報込みに変更

**Files:**
- Modify: `config/tmux-agent-sidebar-rs/tests/ui_snapshot.rs`

- [ ] **Step 1: buffer_to_styled_stringヘルパーを追加**

テストファイルのbuffer_to_string関数をスタイル情報込みに変更:

```rust
use ratatui::style::{Color, Modifier};

/// Convert a ratatui Buffer to a styled string for snapshot comparison.
/// Format per cell: if style differs from default, append style annotation.
/// Example: "○" with fg=250 → "○[fg:250]", "●" with fg=82 → "●[fg:82]"
/// Reversed text: "text[rev]"
/// Bold text: "text[bold]"
/// Multiple: "text[fg:255,bold]"
fn buffer_to_styled_string(buf: &Buffer) -> String {
    let area = buf.area;
    let mut lines = Vec::new();
    for y in area.y..area.y + area.height {
        let mut line = String::new();
        for x in area.x..area.x + area.width {
            let cell = &buf[(x, y)];
            line.push_str(cell.symbol());

            let mut attrs = Vec::new();
            if let Color::Indexed(n) = cell.fg {
                attrs.push(format!("fg:{n}"));
            }
            if let Color::Indexed(n) = cell.bg {
                attrs.push(format!("bg:{n}"));
            }
            if cell.modifier.contains(Modifier::BOLD) {
                attrs.push("bold".into());
            }
            if cell.modifier.contains(Modifier::REVERSED) {
                attrs.push("rev".into());
            }
            if !attrs.is_empty() {
                line.push_str(&format!("[{}]", attrs.join(",")));
            }
        }
        lines.push(line.trim_end().to_string());
    }
    while lines.last().is_some_and(|l| l.is_empty()) {
        lines.pop();
    }
    lines.join("\n")
}
```

- [ ] **Step 2: render_to_styled_string関数を追加**

```rust
fn render_to_styled_string(state: &mut AppState, width: u16, height: u16) -> String {
    let backend = TestBackend::new(width, height);
    let mut terminal = Terminal::new(backend).unwrap();
    terminal.draw(|frame| ui::draw(frame, state)).unwrap();

    let buf = terminal.backend().buffer().clone();
    buffer_to_styled_string(&buf)
}
```

- [ ] **Step 3: 既存テストをスタイル込みに移行**

全てのsnapshot_*テストで`render_to_string`→`render_to_styled_string`に変更し、スナップショット名に`_styled`サフィックスを追加（旧スナップショットは削除）。

例:
```rust
#[test]
fn snapshot_single_agent_idle() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);

    let output = render_to_styled_string(&mut state, 28, 10);
    insta::assert_snapshot!("single_agent_idle_styled", output);
}
```

全テスト同様に変更。

- [ ] **Step 4: 旧スナップショットファイルを削除**

```bash
rm config/tmux-agent-sidebar-rs/tests/snapshots/ui_snapshot__*.snap
```

- [ ] **Step 5: テスト実行して新スナップショット生成**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 全テスト失敗（新スナップショットが`.snap.new`に生成される）

- [ ] **Step 6: スナップショット確認・承認**

Run: `cd config/tmux-agent-sidebar-rs && cargo insta accept --all 2>&1`
Expected: 全スナップショット承認

- [ ] **Step 7: テスト再実行して全パス確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 全テストパス

- [ ] **Step 8: Commit**

```bash
git add -A config/tmux-agent-sidebar-rs/tests/
git commit -m "test: migrate snapshots to styled format with color/modifier annotations"
```

---

### Task 7: テストケース拡充

**Files:**
- Modify: `config/tmux-agent-sidebar-rs/tests/ui_snapshot.rs`

- [ ] **Step 1: state遷移テストを追加**

```rust
#[test]
fn test_move_agent_selection_bounds() {
    let mut state = make_state(vec![]);
    state.agent_row_targets = vec![
        RowTarget { window_id: "@1".into(), pane_id: "%1".into() },
        RowTarget { window_id: "@1".into(), pane_id: "%2".into() },
    ];
    state.selected_agent_row = 0;

    state.move_agent_selection(1);
    assert_eq!(state.selected_agent_row, 1);

    // Should not go past end
    state.move_agent_selection(1);
    assert_eq!(state.selected_agent_row, 1);

    state.move_agent_selection(-1);
    assert_eq!(state.selected_agent_row, 0);

    // Should not go below 0
    state.move_agent_selection(-1);
    assert_eq!(state.selected_agent_row, 0);
}

#[test]
fn test_move_agent_selection_empty() {
    let mut state = make_state(vec![]);
    state.move_agent_selection(1);
    assert_eq!(state.selected_agent_row, 0);
}

#[test]
fn test_toggle_focus() {
    let mut state = make_state(vec![]);
    assert_eq!(state.focus, Focus::Agents);
    state.toggle_focus();
    assert_eq!(state.focus, Focus::ActivityLog);
    state.toggle_focus();
    assert_eq!(state.focus, Focus::Agents);
}

#[test]
fn test_scroll_activity_bounds() {
    let mut state = make_state(vec![]);
    state.activity_entries = vec![
        ActivityEntry { timestamp: "10:00".into(), tool: "Read".into(), label: "a".into() },
        ActivityEntry { timestamp: "10:01".into(), tool: "Edit".into(), label: "b".into() },
        ActivityEntry { timestamp: "10:02".into(), tool: "Bash".into(), label: "c".into() },
    ];
    state.activity_total_lines = 6; // 3 entries × 2 lines
    state.activity_visible_height = 4;
    // max scroll = 6 - 4 = 2

    state.scroll_activity(1);
    assert_eq!(state.activity_scroll_offset, 1);

    state.scroll_activity(5); // should clamp to 2
    assert_eq!(state.activity_scroll_offset, 2);

    state.scroll_activity(-10); // should clamp to 0
    assert_eq!(state.activity_scroll_offset, 0);
}
```

- [ ] **Step 2: line_to_rowマッピングテストを追加**

```rust
#[test]
fn test_line_to_row_single_agent() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);

    let _ = render_to_styled_string(&mut state, 28, 10);

    // Row 0: box top (None), Row 1: agent status (Some(0)), Row 2: box bottom (None)
    assert_eq!(state.line_to_row[0], None);    // ╭ project ───╮
    assert_eq!(state.line_to_row[1], Some(0)); // │ ○ claude   │
    assert_eq!(state.line_to_row[2], None);    // ╰────────────╯
}

#[test]
fn test_line_to_row_two_agents() {
    let pane1 = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut pane2 = make_pane(AgentType::Codex, PaneStatus::Idle);
    pane2.pane_id = "%2".into();
    pane2.pane_active = false;

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane1, pane2],
        }],
    }]);

    let _ = render_to_styled_string(&mut state, 28, 10);

    assert_eq!(state.line_to_row[0], None);    // box top
    assert_eq!(state.line_to_row[1], Some(0)); // claude status
    assert_eq!(state.line_to_row[2], None);    // separator
    assert_eq!(state.line_to_row[3], Some(1)); // codex status
    assert_eq!(state.line_to_row[4], None);    // box bottom
}

#[test]
fn test_line_to_row_with_prompt() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    pane.prompt = "hello".into();

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);

    let _ = render_to_styled_string(&mut state, 28, 10);

    assert_eq!(state.line_to_row[0], None);    // box top
    assert_eq!(state.line_to_row[1], Some(0)); // status line
    assert_eq!(state.line_to_row[2], Some(0)); // prompt line (same agent)
    assert_eq!(state.line_to_row[3], None);    // box bottom
}
```

- [ ] **Step 3: 選択行のスタイルテストを追加**

```rust
#[test]
fn snapshot_selected_focused_styled() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);
    state.sidebar_focused = true;
    state.selected_agent_row = 0;

    let output = render_to_styled_string(&mut state, 28, 10);
    // Verify REVERSED modifier is present in the selected row
    assert!(output.contains("[rev]"), "Selected row should have [rev] modifier");
    insta::assert_snapshot!("selected_focused_styled", output);
}
```

- [ ] **Step 4: Activity logのフォーカス色テストを追加**

```rust
#[test]
fn snapshot_activity_focused_styled() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);
    state.activity_entries = vec![
        ActivityEntry { timestamp: "10:32".into(), tool: "Edit".into(), label: "main.rs".into() },
    ];
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;

    let output = render_to_styled_string(&mut state, 28, 16);
    // Activity border should use BORDER_ACTIVE (117) when focused
    assert!(output.contains("fg:117"), "Activity border should be cyan when focused");
    insta::assert_snapshot!("activity_focused_styled", output);
}

#[test]
fn snapshot_activity_unfocused_styled() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);
    state.activity_entries = vec![
        ActivityEntry { timestamp: "10:32".into(), tool: "Edit".into(), label: "main.rs".into() },
    ];
    state.focus = Focus::Agents; // not focused on activity
    state.sidebar_focused = true;

    let output = render_to_styled_string(&mut state, 28, 16);
    insta::assert_snapshot!("activity_unfocused_styled", output);
}
```

- [ ] **Step 5: テスト実行→スナップショット承認→全パス確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Run: `cd config/tmux-agent-sidebar-rs && cargo insta accept --all 2>&1`
Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 全テストパス

- [ ] **Step 6: Commit**

```bash
git add -A config/tmux-agent-sidebar-rs/tests/
git commit -m "test: add state transition, line_to_row, and styled UI snapshot tests"
```

---

### Task 8: text.rsのユニットテスト追加

**Files:**
- Modify: `config/tmux-agent-sidebar-rs/src/ui/text.rs`

- [ ] **Step 1: text.rsにテストモジュールを追加**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_display_width_ascii() {
        assert_eq!(display_width("hello"), 5);
    }

    #[test]
    fn test_display_width_cjk() {
        assert_eq!(display_width("日本語"), 6);
    }

    #[test]
    fn test_display_width_mixed() {
        assert_eq!(display_width("hello世界"), 9);
    }

    #[test]
    fn test_pad_to() {
        assert_eq!(pad_to(3, 8), "     ");
        assert_eq!(pad_to(10, 8), "");
    }

    #[test]
    fn test_wrap_text_short() {
        let result = wrap_text("hello", 10, 3);
        assert_eq!(result, vec!["hello"]);
    }

    #[test]
    fn test_wrap_text_exact_width() {
        let result = wrap_text("hello", 5, 3);
        assert_eq!(result, vec!["hello"]);
    }

    #[test]
    fn test_wrap_text_wraps_at_space() {
        let result = wrap_text("hello world foo", 10, 3);
        assert_eq!(result, vec!["hello", "world foo"]);
    }

    #[test]
    fn test_wrap_text_truncates_with_ellipsis() {
        let result = wrap_text("a very long string that should be truncated", 10, 1);
        assert_eq!(result.len(), 1);
        assert!(result[0].ends_with('…'));
    }

    #[test]
    fn test_wrap_text_cjk() {
        let result = wrap_text("日本語テスト", 6, 3);
        // 日本語 = 6 cols, テスト = 6 cols
        assert_eq!(result.len(), 2);
        assert_eq!(result[0], "日本語");
    }

    #[test]
    fn test_wrap_text_zero_width() {
        assert!(wrap_text("text", 0, 3).is_empty());
    }

    #[test]
    fn test_wrap_text_zero_lines() {
        assert!(wrap_text("text", 10, 0).is_empty());
    }

    #[test]
    fn test_elapsed_label_seconds() {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let result = elapsed_label(Some(now - 45));
        assert_eq!(result, "45s");
    }

    #[test]
    fn test_elapsed_label_minutes() {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let result = elapsed_label(Some(now - 125));
        assert_eq!(result, "2m5s");
    }

    #[test]
    fn test_elapsed_label_none() {
        assert_eq!(elapsed_label(None), "");
    }

    #[test]
    fn test_elapsed_label_zero() {
        assert_eq!(elapsed_label(Some(0)), "");
    }

    #[test]
    fn test_wait_reason_label_known() {
        assert_eq!(wait_reason_label("permission_prompt"), "permission required");
        assert_eq!(wait_reason_label("idle_prompt"), "waiting for input");
    }

    #[test]
    fn test_wait_reason_label_unknown() {
        assert_eq!(wait_reason_label("custom_reason"), "custom_reason");
    }

    #[test]
    fn test_wait_reason_label_empty() {
        assert_eq!(wait_reason_label(""), "");
    }

    #[test]
    fn test_window_title_fixed_name() {
        let window = WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "my-window".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![],
        };
        assert_eq!(window_title(&window), "my-window");
    }

    #[test]
    fn test_window_title_auto_rename() {
        use crate::tmux::{AgentType, PaneStatus};
        let window = WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "fish".into(),
            window_active: true,
            auto_rename: true,
            panes: vec![crate::tmux::PaneInfo {
                pane_id: "%1".into(),
                pane_active: true,
                status: PaneStatus::Idle,
                attention: false,
                agent: AgentType::Claude,
                pane_name: String::new(),
                path: "/home/user/project".into(),
                command: "fish".into(),
                role: String::new(),
                prompt: String::new(),
                started_at: None,
                wait_reason: String::new(),
            }],
        };
        assert_eq!(window_title(&window), "project");
    }
}
```

- [ ] **Step 2: テスト実行**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 全テストパス

- [ ] **Step 3: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui/text.rs
git commit -m "test: add comprehensive unit tests for ui/text.rs helpers"
```

---

### Task 9: リリースビルドと最終確認

**Files:**
- None (ビルド・テストのみ)

- [ ] **Step 1: 全テスト実行**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 全テストパス

- [ ] **Step 2: リリースビルド**

Run: `cd config/tmux-agent-sidebar-rs && cargo build --release 2>&1`
Expected: コンパイル成功、警告なし

- [ ] **Step 3: Commit（全変更が含まれていることを確認）**

```bash
git status
```

Expected: nothing to commit, working tree clean
