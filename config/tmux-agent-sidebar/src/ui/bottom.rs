use ratatui::{
    Frame,
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph},
};

use crate::state::{AppState, BottomTab};

use super::text::{display_width, pad_to, truncate_to_width, wrap_text_char};

const MAX_CHANGED_FILES: usize = 5;

fn render_centered(frame: &mut Frame, area: Rect, text: &str, color: Color) {
    // Vertically center: pad with empty lines above
    let top_pad = area.height.saturating_sub(1) / 2;
    let mut lines: Vec<Line<'_>> = Vec::new();
    for _ in 0..top_pad {
        lines.push(Line::from(""));
    }
    lines.push(Line::from(Span::styled(text, Style::default().fg(color))));
    let paragraph = Paragraph::new(lines).alignment(Alignment::Center);
    frame.render_widget(paragraph, area);
}

pub fn draw_bottom(frame: &mut Frame, state: &mut AppState, area: Rect) {
    let theme = &state.theme;
    let border_color = theme.border_active;

    // Build the tab bar title
    let tab_title = build_tab_title(state);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .title(tab_title)
        .style(Style::default().fg(border_color));

    let inner = block.inner(area);
    frame.render_widget(block, area);

    match state.bottom_tab {
        BottomTab::Activity => draw_activity_content(frame, state, inner),
        BottomTab::GitStatus => draw_git_content(frame, state, inner),
    }
}

fn build_tab_title(state: &AppState) -> Line<'static> {
    let theme = &state.theme;

    let activity_style = if state.bottom_tab == BottomTab::Activity {
        Style::default()
            .fg(theme.text_active)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(theme.text_muted)
    };

    let git_style = if state.bottom_tab == BottomTab::GitStatus {
        Style::default()
            .fg(theme.text_active)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(theme.text_muted)
    };

    let sep_style = Style::default().fg(theme.border_inactive);

    Line::from(vec![
        Span::styled(" Activity ", activity_style),
        Span::styled("\u{2502}", sep_style),
        Span::styled(" Git ", git_style),
    ])
}

fn draw_activity_content(frame: &mut Frame, state: &mut AppState, inner: Rect) {
    let theme = &state.theme;

    if state.activity_entries.is_empty() {
        render_centered(frame, inner, "No activity yet", theme.text_muted);
        return;
    }

    let mut lines: Vec<Line<'_>> = Vec::new();
    let inner_w = inner.width as usize;

    for entry in &state.activity_entries {
        let tool_color = Color::Indexed(entry.tool_color_index());

        let ts_dw = display_width(&entry.timestamp);
        let tool_dw = display_width(&entry.tool);
        let gap = pad_to(ts_dw + tool_dw, inner_w);
        let line1 = Line::from(vec![
            Span::styled(
                entry.timestamp.clone(),
                Style::default().fg(theme.activity_timestamp),
            ),
            Span::raw(gap),
            Span::styled(entry.tool.clone(), Style::default().fg(tool_color)),
        ]);
        lines.push(line1);

        if !entry.label.is_empty() {
            let label_max_w = inner_w.saturating_sub(2);
            let wrapped = wrap_text_char(&entry.label, label_max_w, 3);
            for wl in wrapped {
                lines.push(Line::from(Span::styled(
                    format!("  {wl}"),
                    Style::default().fg(theme.text_muted),
                )));
            }
        }
    }

    state.activity_scroll.total_lines = lines.len();
    state.activity_scroll.visible_height = inner.height as usize;

    let scroll_offset = state.activity_scroll.offset as u16;
    let paragraph = Paragraph::new(lines).scroll((scroll_offset, 0));
    frame.render_widget(paragraph, inner);
}

fn render_pr_diff_line(state: &AppState, inner_w: usize) -> Option<Line<'static>> {
    let mut left_spans: Vec<Span> = Vec::new();
    let mut left_w = 0;

    if let Some(ref pr_num) = state.git_pr_number {
        left_spans.push(Span::raw(" "));
        left_w += 1;
        let link_text = format!("#{pr_num}");
        left_w += display_width(&link_text);
        left_spans.push(Span::styled(
            link_text,
            Style::default()
                .fg(state.theme.pr_link)
                .add_modifier(Modifier::UNDERLINED),
        ));
    }

    let mut right_spans: Vec<Span> = Vec::new();
    let mut right_w = 0;

    if let Some((ins, del)) = state.git_diff_stat {
        if ins > 0 {
            let s = format!("+{ins}");
            right_w += display_width(&s);
            right_spans.push(Span::styled(s, Style::default().fg(state.theme.diff_added)));
        }
        if del > 0 {
            let s = format!("-{del}");
            right_w += display_width(&s);
            right_spans.push(Span::styled(
                s,
                Style::default().fg(state.theme.diff_deleted),
            ));
        }
    }

    if left_w > 0 || right_w > 0 {
        let gap = pad_to(left_w + right_w, inner_w);
        let mut spans = left_spans;
        spans.push(Span::raw(gap));
        spans.extend(right_spans);
        Some(Line::from(spans))
    } else {
        None
    }
}

fn render_branch_line(state: &AppState) -> Option<Line<'static>> {
    if state.git_branch.is_empty() {
        return None;
    }

    let theme = &state.theme;
    let mut spans = vec![Span::styled(
        format!(" {}", state.git_branch),
        Style::default().fg(theme.text_active),
    )];

    if let Some((ahead, behind)) = state.git_ahead_behind {
        let mut ab = String::new();
        if ahead > 0 {
            ab.push_str(&format!(" ↑{ahead}"));
        }
        if behind > 0 {
            ab.push_str(&format!(" ↓{behind}"));
        }
        if !ab.is_empty() {
            spans.push(Span::styled(ab, Style::default().fg(theme.text_muted)));
        }
    }

    Some(Line::from(spans))
}

fn render_last_commit_lines(state: &AppState, inner_w: usize) -> Vec<Line<'static>> {
    let theme = &state.theme;
    let mut lines = Vec::new();

    if let Some((ref hash, ref message, epoch)) = state.git_last_commit {
        lines.push(Line::from(""));
        let ago = relative_time(epoch, state.now);
        let ago_w = display_width(&ago) + 1;
        let hash_text = format!(" {hash}");
        let hash_w = display_width(&hash_text);
        let gap = pad_to(hash_w + ago_w, inner_w);
        lines.push(Line::from(vec![
            Span::styled(hash_text, Style::default().fg(theme.commit_hash)),
            Span::raw(gap),
            Span::styled(format!("{ago} "), Style::default().fg(theme.text_muted)),
        ]));
        let max_msg_w = inner_w.saturating_sub(2);
        let truncated = truncate_to_width(message, max_msg_w);
        lines.push(Line::from(Span::styled(
            format!("  {truncated}"),
            Style::default().fg(theme.text_muted),
        )));
    }

    lines
}

fn render_file_changes(state: &AppState, inner_w: usize) -> Vec<Line<'static>> {
    let theme = &state.theme;
    let mut lines = Vec::new();

    // File count summary by status
    let summary = git_status_summary(&state.git_status_lines, theme);
    for (label, count, color) in &summary {
        if *count > 0 {
            lines.push(Line::from(vec![
                Span::styled(format!(" {label}: "), Style::default().fg(theme.text_muted)),
                Span::styled(format!("{count}"), Style::default().fg(*color)),
            ]));
        }
    }

    // Top changed files (by lines changed)
    if !state.git_file_changes.is_empty() {
        lines.push(Line::from(""));
        for (name, change_size) in state.git_file_changes.iter().take(MAX_CHANGED_FILES) {
            let stat = format!("±{change_size} ");
            let stat_w = display_width(&stat);
            let max_name_w = inner_w.saturating_sub(stat_w + 2);
            let truncated_name = truncate_to_width(name, max_name_w);
            let label = format!(" {truncated_name}");
            let label_w = display_width(&label);
            let gap = pad_to(label_w + stat_w, inner_w);
            lines.push(Line::from(vec![
                Span::styled(label, Style::default().fg(theme.text_muted)),
                Span::raw(gap),
                Span::styled(stat, Style::default().fg(theme.file_change)),
            ]));
        }
        let total = state.git_file_changes.len();
        if total > MAX_CHANGED_FILES {
            lines.push(Line::from(Span::styled(
                format!(" +{} more", total - MAX_CHANGED_FILES),
                Style::default().fg(theme.text_muted),
            )));
        }
    }

    lines
}

fn draw_git_content(frame: &mut Frame, state: &mut AppState, inner: Rect) {
    let theme = &state.theme;
    let inner_w = inner.width as usize;

    // Show centered "Working tree clean" only when git data has not loaded yet
    // (no branch info at all). Once git data arrives, the inline check below
    // handles the clean-tree case consistently.
    if state.git_branch.is_empty()
        && state.git_status_lines.is_empty()
        && state.git_diff_stat.is_none()
        && state.git_last_commit.is_none()
    {
        render_centered(frame, inner, "Working tree clean", theme.text_muted);
        return;
    }

    let mut lines: Vec<Line<'_>> = Vec::new();

    if let Some(line) = render_pr_diff_line(state, inner_w) {
        lines.push(line);
        lines.push(Line::from(""));
    }
    if let Some(line) = render_branch_line(state) {
        lines.push(line);
    }
    lines.extend(render_last_commit_lines(state, inner_w));
    if !lines.is_empty() {
        lines.push(Line::from(""));
    }
    lines.extend(render_file_changes(state, inner_w));

    // "Working tree clean" if no file changes and no commit
    if state.git_status_lines.is_empty()
        && state.git_file_changes.is_empty()
        && state.git_last_commit.is_none()
    {
        lines.push(Line::from(Span::styled(
            " Working tree clean",
            Style::default().fg(theme.text_muted),
        )));
    }

    state.git_scroll.total_lines = lines.len();
    state.git_scroll.visible_height = inner.height as usize;

    let scroll_offset = state.git_scroll.offset as u16;
    let paragraph = Paragraph::new(lines).scroll((scroll_offset, 0));
    frame.render_widget(paragraph, inner);
}

pub(crate) fn git_status_summary(
    status_lines: &[String],
    theme: &crate::ui::colors::ColorTheme,
) -> Vec<(&'static str, usize, Color)> {
    let mut modified = 0;
    let mut added = 0;
    let mut deleted = 0;
    let mut untracked = 0;

    for line in status_lines {
        let trimmed = line.trim_start();
        if trimmed.starts_with("M ") || trimmed.starts_with("MM") || trimmed.starts_with(" M") {
            modified += 1;
        } else if trimmed.starts_with("A ") || trimmed.starts_with("AM") {
            added += 1;
        } else if trimmed.starts_with("D ") || trimmed.starts_with(" D") {
            deleted += 1;
        } else if trimmed.starts_with("??") {
            untracked += 1;
        } else if !trimmed.is_empty() {
            // Covers renamed (R), copied (C), conflicts (UU/AA), and other states
            modified += 1;
        }
    }

    vec![
        ("Modified", modified, theme.badge_auto),
        ("Added", added, theme.status_running),
        ("Deleted", deleted, theme.badge_danger),
        ("Untracked", untracked, theme.text_muted),
    ]
}

/// Relative time string from epoch seconds
pub(crate) fn relative_time(epoch: u64, now: u64) -> String {
    let diff = now.saturating_sub(epoch);
    if diff < 60 {
        format!("{diff}s ago")
    } else if diff < 3600 {
        format!("{}m ago", diff / 60)
    } else if diff < 86400 {
        format!("{}h ago", diff / 3600)
    } else {
        format!("{}d ago", diff / 86400)
    }
}

#[cfg(test)]
fn line_text(line: &Line<'_>) -> String {
    line.spans
        .iter()
        .map(|span| span.content.as_ref())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn git_status_summary_all_types() {
        let lines = vec![
            " M modified.rs".into(),
            "A  added.rs".into(),
            " D deleted.rs".into(),
            "?? untracked.rs".into(),
            "R  old.rs -> new.rs".into(), // rename -> counted as modified
            "UU conflict.rs".into(),      // conflict -> counted as modified
        ];
        let theme = crate::ui::colors::ColorTheme::default();
        let summary = git_status_summary(&lines, &theme);
        // summary order: Modified, Added, Deleted, Untracked
        assert_eq!(summary[0].1, 3); // 1 M + 1 R + 1 UU = 3 modified
        assert_eq!(summary[1].1, 1); // 1 added
        assert_eq!(summary[2].1, 1); // 1 deleted
        assert_eq!(summary[3].1, 1); // 1 untracked
    }

    #[test]
    fn git_status_summary_empty() {
        let theme = crate::ui::colors::ColorTheme::default();
        let summary = git_status_summary(&[], &theme);
        for (_, count, _) in &summary {
            assert_eq!(*count, 0);
        }
    }

    #[test]
    fn render_last_commit_lines_uses_state_now() {
        let mut state = crate::state::AppState::new(String::new());
        state.now = 1_000_000;
        state.git_last_commit = Some(("abc1234".into(), "fix bug".into(), 1_000_000 - 300));

        let lines = render_last_commit_lines(&state, 40);
        assert!(line_text(&lines[1]).contains("5m ago"));
    }

    #[test]
    fn relative_time_seconds() {
        const TEST_NOW: u64 = 1_000_000;
        assert_eq!(relative_time(TEST_NOW - 30, TEST_NOW), "30s ago");
    }

    #[test]
    fn relative_time_minutes() {
        const TEST_NOW: u64 = 1_000_000;
        assert_eq!(relative_time(TEST_NOW - 90, TEST_NOW), "1m ago");
    }

    #[test]
    fn relative_time_hours() {
        const TEST_NOW: u64 = 1_000_000;
        assert_eq!(relative_time(TEST_NOW - 7200, TEST_NOW), "2h ago");
    }

    #[test]
    fn relative_time_days() {
        const TEST_NOW: u64 = 1_000_000;
        assert_eq!(relative_time(TEST_NOW - 172800, TEST_NOW), "2d ago");
    }

    #[test]
    fn truncate_to_width_short() {
        assert_eq!(truncate_to_width("hello", 10), "hello");
    }

    #[test]
    fn truncate_to_width_exact() {
        assert_eq!(truncate_to_width("hello", 5), "hello");
    }

    #[test]
    fn truncate_to_width_truncated() {
        let result = truncate_to_width("hello world", 8);
        assert!(result.ends_with('…'));
        assert!(result.len() <= 10); // 7 chars + ellipsis in bytes
    }

    #[test]
    fn render_pr_diff_line_compacts_insertions_and_deletions() {
        let mut state = crate::state::AppState::new(String::new());
        state.git_pr_number = Some("42".into());
        state.git_diff_stat = Some((3, 1));

        let line = render_pr_diff_line(&state, 40).expect("expected diff line");
        let text = line_text(&line);

        assert!(text.contains("#42"));
        assert!(text.contains("+3-1"));
        assert!(!text.contains("+3 -1"));
    }
}
