# tmux-agent-sidebar Rust版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** shell版sidebar.shをRust(ratatui+crossterm)で置き換え、マウスクリックによるペイン移動とactivity logスクロールを実現する

**Architecture:** ratatui+crosstermでTUI描画。1秒ポーリングでtmuxコマンドを実行し状態取得。crossterm EventStreamでキーボード・マウスイベントを処理。既存のhook.sh/activity-log.sh等のshellスクリプトはそのまま維持。

**Tech Stack:** Rust, ratatui, crossterm

---

## File Structure

```
config/tmux-agent-sidebar-rs/
├── Cargo.toml
├── src/
│   ├── main.rs        # エントリポイント、イベントループ
│   ├── tmux.rs        # tmuxコマンド実行・パース
│   ├── state.rs       # アプリケーション状態管理
│   ├── ui.rs          # ratatui描画
│   └── activity.rs    # activity logファイルパース
```

修正対象:
- `config/tmux-agent-sidebar/scripts/sidebar-toggle.sh` — Rustバイナリがあれば優先起動

---

### Task 1: Rustプロジェクトスキャフォールド

**Files:**
- Create: `config/tmux-agent-sidebar-rs/Cargo.toml`
- Create: `config/tmux-agent-sidebar-rs/src/main.rs`

- [ ] **Step 1: Cargo.toml作成**

```toml
[package]
name = "tmux-agent-sidebar"
version = "0.1.0"
edition = "2024"

[dependencies]
ratatui = "0.29"
crossterm = "0.29"

[profile.release]
strip = true
lto = true
```

- [ ] **Step 2: 最小限のmain.rs作成**

```rust
use std::io;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

fn main() -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    terminal.draw(|frame| {
        let area = frame.area();
        frame.render_widget(
            ratatui::widgets::Paragraph::new("tmux-agent-sidebar (rust)"),
            area,
        );
    })?;

    loop {
        if event::poll(std::time::Duration::from_secs(1))? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('q') {
                    break;
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    Ok(())
}
```

- [ ] **Step 3: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功

- [ ] **Step 4: Commit**

```bash
git add config/tmux-agent-sidebar-rs/Cargo.toml config/tmux-agent-sidebar-rs/src/main.rs
git commit -m "feat: scaffold Rust sidebar project with ratatui + crossterm"
```

---

### Task 2: tmuxデータ取得レイヤー

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/tmux.rs`
- Modify: `config/tmux-agent-sidebar-rs/src/main.rs` (mod宣言追加)

- [ ] **Step 1: tmux.rsのデータ型を定義**

```rust
use std::process::Command;

#[derive(Debug, Clone)]
pub struct PaneInfo {
    pub pane_id: String,
    pub pane_active: bool,
    pub status: PaneStatus,
    pub attention: bool,
    pub agent: AgentType,
    pub pane_name: String,
    pub path: String,
    pub command: String,
    pub role: String,
    pub prompt: String,
    pub started_at: Option<u64>,
    pub wait_reason: String,
}

#[derive(Debug, Clone, PartialEq)]
pub enum PaneStatus {
    Running,
    Waiting,
    Idle,
    Error,
    Unknown,
}

#[derive(Debug, Clone, PartialEq)]
pub enum AgentType {
    Claude,
    Codex,
    Unknown,
}

#[derive(Debug, Clone)]
pub struct WindowInfo {
    pub window_id: String,
    pub window_index: u32,
    pub window_name: String,
    pub window_active: bool,
    pub auto_rename: bool,
    pub panes: Vec<PaneInfo>,
}

#[derive(Debug, Clone)]
pub struct SessionInfo {
    pub session_name: String,
    pub attached: bool,
    pub windows: Vec<WindowInfo>,
}
```

- [ ] **Step 2: tmuxコマンド実行とパース関数を実装**

```rust
impl AgentType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "claude" => Some(Self::Claude),
            "codex" => Some(Self::Codex),
            _ => None,
        }
    }

    pub fn label(&self) -> &str {
        match self {
            Self::Claude => "claude",
            Self::Codex => "codex",
            Self::Unknown => "unknown",
        }
    }
}

impl PaneStatus {
    pub fn from_str(s: &str) -> Self {
        match s {
            "running" => Self::Running,
            "waiting" | "notification" => Self::Waiting,
            "idle" => Self::Idle,
            "error" => Self::Error,
            _ => Self::Unknown,
        }
    }

    pub fn icon(&self) -> &str {
        match self {
            Self::Running => "●",
            Self::Waiting => "◐",
            Self::Idle => "○",
            Self::Error => "✕",
            Self::Unknown => "·",
        }
    }
}

fn run_tmux(args: &[&str]) -> Option<String> {
    let output = Command::new("tmux")
        .args(args)
        .output()
        .ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        None
    }
}

pub fn query_sessions() -> Vec<SessionInfo> {
    let session_output = match run_tmux(&[
        "list-sessions",
        "-F",
        "#{session_name}|#{session_attached}|#{session_windows}",
    ]) {
        Some(s) => s,
        None => return vec![],
    };

    let mut sessions = Vec::new();

    for line in session_output.lines() {
        let parts: Vec<&str> = line.splitn(3, '|').collect();
        if parts.len() < 3 {
            continue;
        }
        let session_name = parts[0].to_string();
        let attached = parts[1] == "1";

        let windows = query_windows(&session_name);
        if windows.iter().any(|w| !w.panes.is_empty()) {
            sessions.push(SessionInfo {
                session_name,
                attached,
                windows,
            });
        }
    }

    sessions
}

fn query_windows(session_name: &str) -> Vec<WindowInfo> {
    let window_output = match run_tmux(&[
        "list-windows",
        "-t",
        session_name,
        "-F",
        "#{window_id}|#{window_index}|#{window_name}|#{window_active}|#{automatic-rename}",
    ]) {
        Some(s) => s,
        None => return vec![],
    };

    let mut windows = Vec::new();

    for line in window_output.lines() {
        let parts: Vec<&str> = line.splitn(5, '|').collect();
        if parts.len() < 5 {
            continue;
        }

        let panes = query_panes(parts[0]);
        windows.push(WindowInfo {
            window_id: parts[0].to_string(),
            window_index: parts[1].parse().unwrap_or(0),
            window_name: parts[2].to_string(),
            window_active: parts[3] == "1",
            auto_rename: parts[4] == "1",
            panes,
        });
    }

    windows
}

fn query_panes(window_id: &str) -> Vec<PaneInfo> {
    let pane_output = match run_tmux(&[
        "list-panes",
        "-t",
        window_id,
        "-F",
        "#{pane_active}|#{@pane_status}|#{@pane_attention}|#{@pane_agent}|#{@pane_name}|#{pane_current_path}|#{pane_current_command}|#{@pane_role}|#{pane_id}|#{@pane_prompt}|#{@pane_started_at}|#{@pane_wait_reason}",
    ]) {
        Some(s) => s,
        None => return vec![],
    };

    let mut panes = Vec::new();

    for line in pane_output.lines() {
        let parts: Vec<&str> = line.splitn(12, '|').collect();
        if parts.len() < 12 {
            continue;
        }

        // Skip sidebar panes
        if parts[7] == "sidebar" {
            continue;
        }

        // Only include agent panes
        let agent = match AgentType::from_str(parts[3]) {
            Some(a) => a,
            None => continue,
        };

        panes.push(PaneInfo {
            pane_active: parts[0] == "1",
            status: PaneStatus::from_str(parts[1]),
            attention: !parts[2].is_empty(),
            agent,
            pane_name: parts[4].to_string(),
            path: parts[5].to_string(),
            command: parts[6].to_string(),
            role: parts[7].to_string(),
            pane_id: parts[8].to_string(),
            prompt: parts[9].replace('|', " ").replace('\n', " "),
            started_at: parts[10].parse().ok(),
            wait_reason: parts[11].to_string(),
        });
    }

    panes
}

pub fn get_sidebar_pane_info(tmux_pane: &str) -> (bool, u16, u16) {
    let output = run_tmux(&[
        "display-message",
        "-t",
        tmux_pane,
        "-p",
        "#{pane_active} #{pane_width} #{pane_height}",
    ]);
    match output {
        Some(s) => {
            let parts: Vec<&str> = s.trim().splitn(3, ' ').collect();
            if parts.len() >= 3 {
                (
                    parts[0] == "1",
                    parts[1].parse().unwrap_or(28),
                    parts[2].parse().unwrap_or(24),
                )
            } else {
                (false, 28, 24)
            }
        }
        None => (false, 28, 24),
    }
}

pub fn select_pane(window_id: &str, pane_id: &str) {
    let _ = run_tmux(&["select-window", "-t", window_id]);
    let _ = run_tmux(&["select-pane", "-t", pane_id]);
}
```

- [ ] **Step 3: main.rsにmod宣言追加**

main.rsの先頭に追加:
```rust
mod tmux;
```

- [ ] **Step 4: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功

- [ ] **Step 5: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/tmux.rs config/tmux-agent-sidebar-rs/src/main.rs
git commit -m "feat: add tmux data query layer with session/window/pane parsing"
```

---

### Task 3: Activity Logパーサー

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/activity.rs`
- Modify: `config/tmux-agent-sidebar-rs/src/main.rs` (mod宣言追加)

- [ ] **Step 1: activity.rsを実装**

```rust
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct ActivityEntry {
    pub timestamp: String,
    pub tool: String,
    pub label: String,
}

impl ActivityEntry {
    pub fn tool_color_index(&self) -> u8 {
        match self.tool.as_str() {
            "Edit" | "Write" => 221,  // yellow
            "Bash" => 82,             // green
            "Read" | "Glob" | "Grep" => 39,  // blue
            "Agent" => 174,           // terracotta
            _ => 244,                 // muted
        }
    }
}

pub fn log_file_path(pane_id: &str) -> PathBuf {
    let encoded = pane_id.replace('%', "_");
    PathBuf::from(format!("/tmp/tmux-agent-activity{encoded}.log"))
}

pub fn read_activity_log(pane_id: &str, max_entries: usize) -> Vec<ActivityEntry> {
    let path = log_file_path(pane_id);
    let content = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return vec![],
    };

    let lines: Vec<&str> = content.lines().collect();
    let start = if lines.len() > max_entries {
        lines.len() - max_entries
    } else {
        0
    };

    lines[start..]
        .iter()
        .rev()  // newest first
        .filter_map(|line| {
            let mut parts = line.splitn(3, '|');
            let timestamp = parts.next()?.to_string();
            let tool = parts.next()?.to_string();
            let label = parts.next().unwrap_or("").to_string();
            Some(ActivityEntry {
                timestamp,
                tool,
                label,
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn test_parse_activity_log() {
        let dir = std::env::temp_dir();
        let path = dir.join("test-activity-log.log");
        let mut f = fs::File::create(&path).unwrap();
        writeln!(f, "10:30|Read|package.json").unwrap();
        writeln!(f, "10:31|Edit|sidebar.sh").unwrap();
        writeln!(f, "10:32|Bash|cargo build").unwrap();
        drop(f);

        // Read with pane_id trick - test the parser directly
        let content = fs::read_to_string(&path).unwrap();
        let lines: Vec<&str> = content.lines().collect();
        let entries: Vec<ActivityEntry> = lines
            .iter()
            .rev()
            .filter_map(|line| {
                let mut parts = line.splitn(3, '|');
                let timestamp = parts.next()?.to_string();
                let tool = parts.next()?.to_string();
                let label = parts.next().unwrap_or("").to_string();
                Some(ActivityEntry { timestamp, tool, label })
            })
            .collect();

        assert_eq!(entries.len(), 3);
        assert_eq!(entries[0].tool, "Bash");
        assert_eq!(entries[0].label, "cargo build");
        assert_eq!(entries[2].tool, "Read");

        fs::remove_file(&path).unwrap();
    }

    #[test]
    fn test_tool_color() {
        let entry = ActivityEntry {
            timestamp: "10:00".into(),
            tool: "Edit".into(),
            label: "test".into(),
        };
        assert_eq!(entry.tool_color_index(), 221);

        let entry = ActivityEntry {
            timestamp: "10:00".into(),
            tool: "Bash".into(),
            label: "test".into(),
        };
        assert_eq!(entry.tool_color_index(), 82);
    }

    #[test]
    fn test_log_file_path() {
        let path = log_file_path("%5");
        assert_eq!(path.to_str().unwrap(), "/tmp/tmux-agent-activity_5.log");
    }
}
```

- [ ] **Step 2: main.rsにmod宣言追加**

main.rsに追加:
```rust
mod activity;
```

- [ ] **Step 3: テスト実行**

Run: `cd config/tmux-agent-sidebar-rs && cargo test 2>&1`
Expected: 3テストパス

- [ ] **Step 4: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/activity.rs config/tmux-agent-sidebar-rs/src/main.rs
git commit -m "feat: add activity log parser with tests"
```

---

### Task 4: アプリケーション状態管理

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/state.rs`
- Modify: `config/tmux-agent-sidebar-rs/src/main.rs` (mod宣言追加)

- [ ] **Step 1: state.rsを実装**

```rust
use crate::activity::{self, ActivityEntry};
use crate::tmux::{self, PaneStatus, SessionInfo};

#[derive(Debug, Clone, PartialEq)]
pub enum Focus {
    Agents,
    ActivityLog,
}

/// Row target for navigation - maps a selectable row to a window+pane pair
#[derive(Debug, Clone)]
pub struct RowTarget {
    pub window_id: String,
    pub pane_id: String,
}

pub struct AppState {
    pub sessions: Vec<SessionInfo>,
    pub sidebar_focused: bool,
    pub focus: Focus,
    pub selected_agent_row: usize,
    pub agent_row_targets: Vec<RowTarget>,
    pub activity_entries: Vec<ActivityEntry>,
    pub activity_scroll_offset: usize,
    pub focused_pane_id: Option<String>,
    pub tmux_pane: String,
    pub activity_max_entries: usize,
}

impl AppState {
    pub fn new(tmux_pane: String) -> Self {
        Self {
            sessions: vec![],
            sidebar_focused: false,
            focus: Focus::Agents,
            selected_agent_row: 0,
            agent_row_targets: vec![],
            activity_entries: vec![],
            activity_scroll_offset: 0,
            focused_pane_id: None,
            tmux_pane,
            activity_max_entries: 50,
        }
    }

    pub fn refresh(&mut self) {
        let (focused, _, _) = tmux::get_sidebar_pane_info(&self.tmux_pane);
        self.sidebar_focused = focused;
        self.sessions = tmux::query_sessions();
        self.rebuild_row_targets();
        self.find_focused_pane();
        self.refresh_activity_log();
    }

    fn rebuild_row_targets(&mut self) {
        let mut targets = Vec::new();
        for session in &self.sessions {
            for window in &session.windows {
                for pane in &window.panes {
                    targets.push(RowTarget {
                        window_id: window.window_id.clone(),
                        pane_id: pane.pane_id.clone(),
                    });
                }
            }
        }
        self.agent_row_targets = targets;
        if self.selected_agent_row >= self.agent_row_targets.len() && !self.agent_row_targets.is_empty() {
            self.selected_agent_row = self.agent_row_targets.len() - 1;
        }
    }

    fn find_focused_pane(&mut self) {
        self.focused_pane_id = None;
        for session in &self.sessions {
            for window in &session.windows {
                if !window.window_active {
                    continue;
                }
                // Prefer active pane, fall back to first
                let active = window.panes.iter().find(|p| p.pane_active);
                let first = window.panes.first();
                if let Some(pane) = active.or(first) {
                    self.focused_pane_id = Some(pane.pane_id.clone());
                }
                return;
            }
        }
    }

    fn refresh_activity_log(&mut self) {
        if let Some(ref pane_id) = self.focused_pane_id {
            self.activity_entries =
                activity::read_activity_log(pane_id, self.activity_max_entries);
        } else {
            self.activity_entries.clear();
        }
    }

    pub fn move_agent_selection(&mut self, delta: isize) {
        if self.agent_row_targets.is_empty() {
            return;
        }
        let len = self.agent_row_targets.len() as isize;
        let next = self.selected_agent_row as isize + delta;
        if next >= 0 && next < len {
            self.selected_agent_row = next as usize;
        }
    }

    pub fn activate_selection(&self) {
        if let Some(target) = self.agent_row_targets.get(self.selected_agent_row) {
            tmux::select_pane(&target.window_id, &target.pane_id);
        }
    }

    pub fn scroll_activity(&mut self, delta: isize) {
        if self.activity_entries.is_empty() {
            return;
        }
        let max = self.activity_entries.len().saturating_sub(1);
        let next = self.activity_scroll_offset as isize + delta;
        self.activity_scroll_offset = next.max(0).min(max as isize) as usize;
    }

    pub fn toggle_focus(&mut self) {
        self.focus = match self.focus {
            Focus::Agents => Focus::ActivityLog,
            Focus::ActivityLog => Focus::Agents,
        };
    }

    pub fn selected_target(&self) -> Option<&RowTarget> {
        self.agent_row_targets.get(self.selected_agent_row)
    }
}
```

- [ ] **Step 2: main.rsにmod宣言追加**

main.rsに追加:
```rust
mod state;
```

- [ ] **Step 3: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功

- [ ] **Step 4: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/state.rs config/tmux-agent-sidebar-rs/src/main.rs
git commit -m "feat: add application state management with agent/activity navigation"
```

---

### Task 5: UI描画 — エージェントボックス

**Files:**
- Create: `config/tmux-agent-sidebar-rs/src/ui.rs`
- Modify: `config/tmux-agent-sidebar-rs/src/main.rs` (mod宣言追加)

- [ ] **Step 1: ui.rsにカラーヘルパーとelapsed関数を定義**

```rust
use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
};

use crate::state::{AppState, Focus};
use crate::tmux::{AgentType, PaneStatus, SessionInfo, WindowInfo};

fn status_color(status: &PaneStatus, attention: bool) -> Color {
    match status {
        PaneStatus::Running => Color::Indexed(82),
        PaneStatus::Waiting => Color::Indexed(221),
        PaneStatus::Idle => {
            if attention {
                Color::Indexed(203)
            } else {
                Color::Indexed(250)
            }
        }
        PaneStatus::Error => Color::Indexed(203),
        PaneStatus::Unknown => Color::Indexed(244),
    }
}

fn agent_color(agent: &AgentType) -> Color {
    match agent {
        AgentType::Claude => Color::Indexed(174),
        AgentType::Codex => Color::Indexed(141),
        AgentType::Unknown => Color::Indexed(244),
    }
}

fn elapsed_label(started_at: Option<u64>) -> String {
    let Some(started) = started_at else {
        return String::new();
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let diff = now.saturating_sub(started);
    if diff < 60 {
        format!("{diff}s")
    } else if diff < 3600 {
        format!("{}m{}s", diff / 60, diff % 60)
    } else {
        format!("{}h{}m{}s", diff / 3600, (diff % 3600) / 60, diff % 60)
    }
}

fn wait_reason_label(reason: &str) -> &str {
    match reason {
        "permission_prompt" => "permission required",
        "idle_prompt" => "waiting for input",
        "auth_success" => "auth success",
        "elicitation_dialog" => "waiting for selection",
        other if !other.is_empty() => other,
        _ => "",
    }
}
```

- [ ] **Step 2: メイン描画関数を実装**

ui.rsに追加:

```rust
pub fn draw(frame: &mut Frame, state: &AppState) {
    let area = frame.area();

    // Split: top for agents, bottom for activity log
    let has_activity = !state.activity_entries.is_empty();
    let chunks = if has_activity {
        Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(3), Constraint::Length(activity_box_height(state))])
            .split(area)
    } else {
        Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(3)])
            .split(area)
    };

    draw_agents(frame, state, chunks[0]);

    if has_activity && chunks.len() > 1 {
        draw_activity(frame, state, chunks[1]);
    }
}

fn activity_box_height(state: &AppState) -> u16 {
    // Each entry: 1 line for header + 1 line for label = 2 lines, + 2 for borders
    let visible = state.activity_entries.len().min(8);
    (visible as u16 * 2 + 2).min(18)
}

fn draw_agents(frame: &mut Frame, state: &AppState, area: Rect) {
    let mut lines: Vec<Line> = Vec::new();
    let mut row_index: usize = 0;
    let show_session_headers = state.sessions.len() > 1;

    for session in &state.sessions {
        if show_session_headers {
            lines.push(Line::from(Span::styled(
                &session.session_name,
                Style::default()
                    .fg(Color::Indexed(39))
                    .add_modifier(Modifier::BOLD),
            )));
        }

        for window in &session.windows {
            if window.panes.is_empty() {
                continue;
            }

            let border_color = if window.window_active {
                Color::Indexed(117)
            } else {
                Color::Indexed(240)
            };

            let title = window_title(window);
            let title_style = if window.window_active {
                Style::default().fg(Color::Indexed(117))
            } else {
                Style::default().fg(Color::Indexed(244))
            };

            // Box top
            lines.push(Line::from(vec![
                Span::styled("╭ ", Style::default().fg(border_color)),
                Span::styled(&title, title_style.add_modifier(Modifier::BOLD)),
                Span::styled(
                    format!(" {}", "─".repeat(area.width.saturating_sub(title.len() as u16 + 4) as usize)),
                    Style::default().fg(border_color),
                ),
            ]));

            for (i, pane) in window.panes.iter().enumerate() {
                // Separator between agents in same window
                if i > 0 {
                    let dashes = "─".repeat(area.width.saturating_sub(4) as usize);
                    lines.push(Line::from(vec![
                        Span::styled("│ ", Style::default().fg(border_color)),
                        Span::styled(dashes, Style::default().fg(Color::Indexed(240))),
                        Span::styled(" ", Style::default().fg(border_color)),
                    ]));
                }

                let is_selected = state.focus == Focus::Agents
                    && state.sidebar_focused
                    && row_index == state.selected_agent_row;

                let icon_color = status_color(&pane.status, pane.attention);
                let elapsed = elapsed_label(pane.started_at);

                let text_color = match pane.status {
                    PaneStatus::Running | PaneStatus::Waiting => Color::Indexed(255),
                    _ => Color::Indexed(244),
                };

                let ag_color = match pane.status {
                    PaneStatus::Running | PaneStatus::Waiting => Color::Indexed(255),
                    _ => agent_color(&pane.agent),
                };

                let active_mod = if pane.pane_active {
                    Modifier::BOLD
                } else {
                    Modifier::empty()
                };

                let mut spans = vec![
                    Span::styled("│", Style::default().fg(border_color)),
                    Span::styled(
                        format!(" {} ", pane.status.icon()),
                        Style::default().fg(icon_color),
                    ),
                    Span::styled(
                        pane.agent.label(),
                        Style::default().fg(ag_color).add_modifier(active_mod),
                    ),
                ];

                if !elapsed.is_empty() {
                    let label_len = 3 + pane.agent.label().len() + elapsed.len();
                    let pad = (area.width as usize).saturating_sub(label_len + 2);
                    spans.push(Span::raw(" ".repeat(pad)));
                    spans.push(Span::styled(&elapsed, Style::default().fg(text_color)));
                }

                let line = Line::from(spans);
                if is_selected {
                    lines.push(line.patch_style(Style::default().add_modifier(Modifier::REVERSED)));
                } else {
                    lines.push(line);
                }
                row_index += 1;

                // Wait reason
                if !pane.wait_reason.is_empty() {
                    let reason = wait_reason_label(&pane.wait_reason);
                    if !reason.is_empty() {
                        lines.push(Line::from(vec![
                            Span::styled("│", Style::default().fg(border_color)),
                            Span::styled(
                                format!("   {reason}"),
                                Style::default().fg(Color::Indexed(203)),
                            ),
                        ]));
                    }
                }

                // Prompt
                if !pane.prompt.is_empty() {
                    let max_width = area.width.saturating_sub(5) as usize;
                    let prompt_color = if pane.pane_active {
                        Color::Indexed(255)
                    } else {
                        Color::Indexed(244)
                    };
                    for (li, chunk) in wrap_text(&pane.prompt, max_width, 3).iter().enumerate() {
                        let display = if li == 2 && pane.prompt.len() > max_width * 3 {
                            format!("{chunk}…")
                        } else {
                            chunk.to_string()
                        };
                        lines.push(Line::from(vec![
                            Span::styled("│", Style::default().fg(border_color)),
                            Span::styled(
                                format!("   {display}"),
                                Style::default().fg(prompt_color),
                            ),
                        ]));
                    }
                }
            }

            // Box bottom
            lines.push(Line::from(Span::styled(
                format!("╰{}", "─".repeat(area.width.saturating_sub(2) as usize)),
                Style::default().fg(border_color),
            )));
        }
    }

    let paragraph = Paragraph::new(lines);
    frame.render_widget(paragraph, area);
}

fn window_title(window: &WindowInfo) -> String {
    if !window.auto_rename {
        return window.window_name.clone();
    }
    // Use active pane path basename, or first pane
    if let Some(pane) = window.panes.iter().find(|p| p.pane_active).or(window.panes.first()) {
        if !pane.path.is_empty() {
            if let Some(name) = std::path::Path::new(&pane.path).file_name() {
                return name.to_string_lossy().to_string();
            }
        }
    }
    window.window_name.clone()
}

fn wrap_text(text: &str, max_width: usize, max_lines: usize) -> Vec<String> {
    let mut result = Vec::new();
    let mut remaining = text;

    while !remaining.is_empty() && result.len() < max_lines {
        let len = remaining.chars().take(max_width).count();
        let chunk: String = remaining.chars().take(len).collect();
        remaining = &remaining[chunk.len()..];
        result.push(chunk);
    }

    result
}
```

- [ ] **Step 3: main.rsにmod宣言追加**

main.rsに追加:
```rust
mod ui;
```

- [ ] **Step 4: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功

- [ ] **Step 5: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui.rs config/tmux-agent-sidebar-rs/src/main.rs
git commit -m "feat: add ratatui UI rendering for agent boxes and activity log"
```

---

### Task 6: Activity Log描画（スクロール対応）

**Files:**
- Modify: `config/tmux-agent-sidebar-rs/src/ui.rs`

- [ ] **Step 1: draw_activity関数を実装**

ui.rsに追加:

```rust
fn draw_activity(frame: &mut Frame, state: &AppState, area: Rect) {
    let is_focused = state.focus == Focus::ActivityLog && state.sidebar_focused;
    let border_color = if is_focused {
        Color::Indexed(117)
    } else {
        Color::Indexed(39)
    };
    let title_style = Style::default()
        .fg(border_color)
        .add_modifier(Modifier::BOLD);

    let block = Block::default()
        .title(Span::styled("Activity", title_style))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(border_color))
        .border_set(ratatui::symbols::border::Set {
            top_left: "╭",
            top_right: "╮",
            bottom_left: "╰",
            bottom_right: "╯",
            vertical_left: "│",
            vertical_right: "│",
            horizontal_top: "─",
            horizontal_bottom: "─",
        });

    let inner = block.inner(area);
    frame.render_widget(block, area);

    if state.activity_entries.is_empty() {
        return;
    }

    let mut lines: Vec<Line> = Vec::new();
    for entry in &state.activity_entries {
        // Line 1: timestamp + tool name
        let tool_color = Color::Indexed(entry.tool_color_index());
        let pad = inner.width.saturating_sub(entry.timestamp.len() as u16 + entry.tool.len() as u16 + 2);
        lines.push(Line::from(vec![
            Span::styled(
                format!(" {}", entry.timestamp),
                Style::default().fg(Color::Indexed(244)),
            ),
            Span::raw(" ".repeat(pad as usize)),
            Span::styled(&entry.tool, Style::default().fg(tool_color)),
            Span::raw(" "),
        ]));

        // Line 2: label (indented)
        if !entry.label.is_empty() {
            let max_width = inner.width.saturating_sub(4) as usize;
            let display = if entry.label.len() > max_width {
                format!("{}…", &entry.label[..max_width.saturating_sub(1)])
            } else {
                entry.label.clone()
            };
            lines.push(Line::from(Span::styled(
                format!("   {display}"),
                Style::default().fg(Color::Indexed(244)),
            )));
        }
    }

    let total_lines = lines.len() as u16;
    let visible_height = inner.height;
    let max_scroll = total_lines.saturating_sub(visible_height);
    let scroll_offset = (state.activity_scroll_offset as u16).min(max_scroll);

    let paragraph = Paragraph::new(lines).scroll((scroll_offset, 0));
    frame.render_widget(paragraph, inner);

    // Scrollbar when content exceeds view
    if total_lines > visible_height {
        let mut scrollbar_state = ScrollbarState::new(max_scroll as usize)
            .position(scroll_offset as usize);
        let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
            .begin_symbol(None)
            .end_symbol(None);
        frame.render_stateful_widget(
            scrollbar,
            inner,
            &mut scrollbar_state,
        );
    }
}
```

- [ ] **Step 2: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功

- [ ] **Step 3: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/ui.rs
git commit -m "feat: add scrollable activity log with scrollbar"
```

---

### Task 7: イベントループ（キーボード + マウス）

**Files:**
- Modify: `config/tmux-agent-sidebar-rs/src/main.rs` (全面書き換え)

- [ ] **Step 1: main.rsを完全な実装に書き換え**

```rust
use std::io;
use std::time::Duration;

use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, MouseButton, MouseEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

mod activity;
mod state;
mod tmux;
mod ui;

use state::{AppState, Focus};

fn main() -> io::Result<()> {
    let tmux_pane = std::env::var("TMUX_PANE").unwrap_or_default();
    if tmux_pane.is_empty() {
        eprintln!("TMUX_PANE not set");
        std::process::exit(1);
    }

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = run_app(&mut terminal, tmux_pane);

    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;

    result
}

fn run_app(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    tmux_pane: String,
) -> io::Result<()> {
    let mut state = AppState::new(tmux_pane);
    state.refresh();

    loop {
        terminal.draw(|frame| ui::draw(frame, &state))?;

        if event::poll(Duration::from_secs(1))? {
            match event::read()? {
                Event::Key(key) => match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                    KeyCode::Char('j') | KeyCode::Down => match state.focus {
                        Focus::Agents => state.move_agent_selection(1),
                        Focus::ActivityLog => state.scroll_activity(1),
                    },
                    KeyCode::Char('k') | KeyCode::Up => match state.focus {
                        Focus::Agents => state.move_agent_selection(-1),
                        Focus::ActivityLog => state.scroll_activity(-1),
                    },
                    KeyCode::Char('l') | KeyCode::Enter => {
                        if state.focus == Focus::Agents {
                            state.activate_selection();
                        }
                    }
                    KeyCode::Tab => state.toggle_focus(),
                    _ => {}
                },
                Event::Mouse(mouse) => match mouse.kind {
                    MouseEventKind::Down(MouseButton::Left) => {
                        handle_mouse_click(&mut state, mouse.row, mouse.column, terminal.size()?);
                    }
                    MouseEventKind::ScrollUp => {
                        if state.focus == Focus::ActivityLog {
                            state.scroll_activity(-3);
                        } else {
                            state.move_agent_selection(-1);
                        }
                    }
                    MouseEventKind::ScrollDown => {
                        if state.focus == Focus::ActivityLog {
                            state.scroll_activity(3);
                        } else {
                            state.move_agent_selection(1);
                        }
                    }
                    _ => {}
                },
                _ => {}
            }
        }

        // Re-poll tmux state every tick
        state.refresh();
    }
}

fn handle_mouse_click(
    state: &mut AppState,
    row: u16,
    _col: u16,
    size: ratatui::layout::Rect,
) {
    let has_activity = !state.activity_entries.is_empty();
    if !has_activity {
        // All rows are agent area — map row to agent index
        click_agent_row(state, row);
        return;
    }

    // Calculate split point (same logic as ui::draw layout)
    let activity_height = ui::activity_box_height(state);
    let agent_area_height = size.height.saturating_sub(activity_height);

    if row < agent_area_height {
        click_agent_row(state, row);
    } else {
        state.focus = Focus::ActivityLog;
    }
}

fn click_agent_row(state: &mut AppState, row: u16) {
    state.focus = Focus::Agents;
    // Map screen row to agent index by scanning the layout
    // Each agent takes varying rows (status + wait_reason + prompt lines)
    // We count rendered lines to find which agent the click lands on
    let mut line = 0u16;
    let mut agent_idx = 0usize;
    let show_headers = state.sessions.len() > 1;

    for session in &state.sessions {
        if show_headers {
            line += 1; // session header
        }
        for window in &session.windows {
            if window.panes.is_empty() {
                continue;
            }
            line += 1; // box top
            for (i, pane) in window.panes.iter().enumerate() {
                if i > 0 {
                    line += 1; // separator
                }
                let agent_start = line;
                line += 1; // status line
                if !pane.wait_reason.is_empty() && !wait_reason_label_empty(&pane.wait_reason) {
                    line += 1;
                }
                if !pane.prompt.is_empty() {
                    let max_width = 25usize; // approximate
                    let prompt_lines = (pane.prompt.len() / max_width.max(1) + 1).min(3);
                    line += prompt_lines as u16;
                }

                if row >= agent_start && row < line {
                    state.selected_agent_row = agent_idx;
                    state.activate_selection();
                    return;
                }
                agent_idx += 1;
            }
            line += 1; // box bottom
        }
    }
}

fn wait_reason_label_empty(reason: &str) -> bool {
    reason.is_empty()
}
```

- [ ] **Step 2: ui.rsのactivity_box_heightをpubに変更**

ui.rsで `fn activity_box_height` を `pub fn activity_box_height` に変更。

- [ ] **Step 3: ビルド確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo build 2>&1`
Expected: コンパイル成功

- [ ] **Step 4: tmux内で動作確認**

Run: `cd config/tmux-agent-sidebar-rs && cargo run 2>&1`

tmux内で実行してエージェントペインが表示されること、j/k/Enterでナビゲーション、マウスクリックでペイン移動、Tabでactivity logフォーカス切替を確認。

- [ ] **Step 5: Commit**

```bash
git add config/tmux-agent-sidebar-rs/src/main.rs config/tmux-agent-sidebar-rs/src/ui.rs
git commit -m "feat: complete event loop with keyboard, mouse click, and scroll support"
```

---

### Task 8: sidebar-toggle.sh統合

**Files:**
- Modify: `config/tmux-agent-sidebar/scripts/sidebar-toggle.sh`

- [ ] **Step 1: sidebar-toggle.shにRustバイナリ検出を追加**

`sidebar-toggle.sh` の34行目付近、`tmux split-window`の行を以下に変更:

```bash
# Prefer Rust binary if available
rust_bin="$script_dir/../../tmux-agent-sidebar-rs/target/release/tmux-agent-sidebar"
if [ -x "$rust_bin" ]; then
    sidebar_cmd="$rust_bin"
else
    sidebar_cmd="$script_dir/sidebar.sh"
fi

sidebar_pane="$(
    tmux split-window -h -b -l "$sidebar_width" -t "$leftmost_pane" -c "$pane_path" -P -F '#{pane_id}' \
        "$sidebar_cmd"
)"
```

- [ ] **Step 2: Releaseビルド**

Run: `cd config/tmux-agent-sidebar-rs && cargo build --release 2>&1`
Expected: コンパイル成功、`target/release/tmux-agent-sidebar` が生成

- [ ] **Step 3: tmux設定リロードで動作確認**

Run: `tmux source-file ~/.config/tmux/tmux.conf`
prefix + e でサイドバーをトグルし、Rust版が起動されることを確認。

- [ ] **Step 4: Commit**

```bash
git add config/tmux-agent-sidebar/scripts/sidebar-toggle.sh
git commit -m "feat: sidebar-toggle prefers Rust binary when available"
```

---

### Task 9: .gitignore とクリーンアップ

**Files:**
- Create: `config/tmux-agent-sidebar-rs/.gitignore`

- [ ] **Step 1: .gitignore作成**

```
/target
```

- [ ] **Step 2: Commit**

```bash
git add config/tmux-agent-sidebar-rs/.gitignore
git commit -m "chore: add .gitignore for Rust sidebar build artifacts"
```

---

Plan complete and saved to `docs/superpowers/plans/2026-04-03-tmux-sidebar-rust.md`. Two execution options:

**1. Subagent-Driven (recommended)** - タスクごとにサブエージェントを派遣、タスク間でレビュー

**2. Inline Execution** - このセッション内で順次実行

どちらで進めますか？