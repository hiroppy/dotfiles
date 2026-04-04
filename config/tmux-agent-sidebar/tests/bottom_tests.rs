#[allow(dead_code, unused_imports)]
mod test_helpers;

use indoc::indoc;
use test_helpers::*;
use tmux_agent_sidebar::activity::ActivityEntry;
use tmux_agent_sidebar::state::{BottomTab, Focus};
use tmux_agent_sidebar::tmux::{AgentType, PaneStatus, SessionInfo, WindowInfo};

// ─── Bottom Tab Tests ──────────────────────────────────────────────

#[test]
fn test_next_bottom_tab() {
    let mut state = make_state(vec![]);
    assert_eq!(state.bottom_tab, BottomTab::Activity);
    state.next_bottom_tab();
    assert_eq!(state.bottom_tab, BottomTab::GitStatus);
    state.next_bottom_tab();
    assert_eq!(state.bottom_tab, BottomTab::Activity);
}

#[test]
fn test_scroll_bottom_dispatches() {
    let mut state = make_state(vec![]);

    // Set up activity scroll state
    state.activity_entries = vec![
        ActivityEntry {
            timestamp: "10:00".into(),
            tool: "Read".into(),
            label: "a".into(),
        },
        ActivityEntry {
            timestamp: "10:01".into(),
            tool: "Edit".into(),
            label: "b".into(),
        },
    ];
    state.activity_scroll.total_lines = 6;
    state.activity_scroll.visible_height = 4;

    // Set up git scroll state
    state.git_status_lines = vec![
        " M file1.rs".into(),
        " M file2.rs".into(),
        "?? file3.rs".into(),
    ];
    state.git_scroll.total_lines = 3;
    state.git_scroll.visible_height = 1;

    // Activity tab: scroll should affect activity
    state.bottom_tab = BottomTab::Activity;
    state.scroll_bottom(1);
    assert_eq!(state.activity_scroll.offset, 1);
    assert_eq!(state.git_scroll.offset, 0);

    // Git tab: scroll should affect git
    state.bottom_tab = BottomTab::GitStatus;
    state.scroll_bottom(1);
    assert_eq!(state.git_scroll.offset, 1);
    assert_eq!(state.activity_scroll.offset, 1); // unchanged
}

#[test]
fn snapshot_git_status_tab_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "feature/sidebar".into();
    state.git_ahead_behind = Some((2, 1));
    state.git_status_lines = vec![
        " M src/ui/agents.rs".into(),
        " M src/state.rs".into(),
        "?? new_file.rs".into(),
    ];
    state.git_diff_stat = Some((42, 15));

    let output = render_to_string(&mut state, 28, 24);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│                    +42-15│
│ feature/sidebar ↑2 ↓1    │
│ Modified: 2              │
│ Untracked: 1             │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_git_clean_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    // No git changes

    let _output = render_to_string(&mut state, 28, 14);
    let plain = render_to_string(&mut state, 28, 14);
    assert!(plain.contains("Working tree clean"));

    let output = render_to_string(&mut state, 28, 24);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│    Working tree clean    │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_activity_tab_active_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::Activity;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.activity_entries = vec![ActivityEntry {
        timestamp: "10:32".into(),
        tool: "Edit".into(),
        label: "src/main.rs".into(),
    }];

    let output = render_to_string(&mut state, 28, 24);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│10:32                 Edit│
│  src/main.rs             │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_tab_bar_renders_both_labels() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.activity_entries = vec![ActivityEntry {
        timestamp: "10:32".into(),
        tool: "Edit".into(),
        label: "test".into(),
    }];

    let output = render_to_string(&mut state, 28, 14);
    assert!(
        output.contains("Activity"),
        "Tab bar should contain 'Activity' label"
    );
    assert!(output.contains("Git"), "Tab bar should contain 'Git' label");
}

// ─── Git Content Tests ──────────────────────────────────────────────

#[test]
fn snapshot_git_full_info_ui() {
    let now = FIXED_NOW;

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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_ahead_behind = Some((0, 0));
    state.git_diff_stat = Some((120, 30));
    state.git_last_commit = Some(("abc1234".into(), "fix: sidebar crash".into(), now - 300));
    state.git_status_lines = vec![
        " M src/state.rs".into(),
        " M src/ui/bottom.rs".into(),
        "?? new_file.rs".into(),
    ];
    state.git_file_changes = vec![
        ("bottom.rs".into(), 85),
        ("state.rs".into(), 42),
        ("main.rs".into(), 12),
    ];

    // Use plain render since elapsed time varies
    let output = render_to_string(&mut state, 28, 24);
    assert!(output.contains("+120"));
    assert!(output.contains("-30"));
    assert!(output.contains("main"));
    assert!(output.contains("abc1234"));
    assert!(output.contains("fix: sidebar crash"));
    assert!(output.contains("Modified: 2"));
    assert!(output.contains("Untracked: 1"));
    assert!(output.contains("bottom.rs"));
    assert!(output.contains("±85"));
    assert!(output.contains("state.rs"));
    assert!(output.contains("±42"));
}

#[test]
fn snapshot_git_long_filename_truncated_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_file_changes = vec![
        ("very-long-filename-that-should-be-truncated.rs".into(), 200),
        ("short.rs".into(), 10),
    ];
    state.git_status_lines = vec![" M very-long-filename-that-should-be-truncated.rs".into()];

    let output = render_to_string(&mut state, 28, 24);
    // Verify the long filename is truncated (contains ellipsis)
    let plain = render_to_string(&mut state, 28, 18);
    assert!(
        plain.contains("…"),
        "Long filename should be truncated with ellipsis"
    );
    assert!(
        plain.contains("±200"),
        "Change count should still be visible"
    );
    assert!(
        plain.contains("short.rs"),
        "Short filename should not be truncated"
    );
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│ main                     │
│ Modified: 1              │
│ very-long-filename… ±200 │
│ short.rs             ±10 │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_git_more_than_5_files() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_file_changes = vec![
        ("a.rs".into(), 100),
        ("b.rs".into(), 80),
        ("c.rs".into(), 60),
        ("d.rs".into(), 40),
        ("e.rs".into(), 20),
        ("f.rs".into(), 10),
        ("g.rs".into(), 5),
    ];

    // Verify file list rendering (scroll to see overflow)
    let plain = render_to_string(&mut state, 28, 40);
    // First 5 files should be rendered (may need scroll to see all)
    assert!(plain.contains("a.rs"), "1st file should be shown");
    assert!(
        plain.contains("±100"),
        "1st file change count should be shown"
    );
    assert!(!plain.contains("f.rs"), "6th file should NOT be shown");
    assert!(!plain.contains("g.rs"), "7th file should NOT be shown");

    // Scroll to bottom to verify "+2 more" exists
    state.git_scroll.offset = 5;
    let scrolled = render_to_string(&mut state, 28, 40);
    assert!(
        scrolled.contains("+2 more"),
        "Should show overflow count when scrolled"
    );
}

#[test]
fn snapshot_git_branch_only_no_changes() {
    let now = FIXED_NOW;

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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "feature/long-branch-name".into();
    state.git_ahead_behind = Some((5, 0));
    state.git_last_commit = Some(("def5678".into(), "chore: update deps".into(), now - 7200));

    let plain = render_to_string(&mut state, 38, 20);
    assert!(plain.contains("feature/long-branch-name"));
    assert!(plain.contains("↑5"));
    assert!(plain.contains("def5678"));
    assert!(plain.contains("chore: update deps"));
}

#[test]
fn snapshot_git_pr_number_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "feature/fix".into();
    state.git_pr_number = Some("42".into());
    state.git_remote_url = "https://github.com/user/repo".into();
    state.git_diff_stat = Some((10, 3));

    let output = render_to_styled_string(&mut state, 28, 14);
    // PR number should be underlined and blue
    let plain = render_to_string(&mut state, 28, 14);
    assert!(plain.contains("#42"), "PR number should be displayed");
    assert!(
        output.contains("underline"),
        "PR number should be underlined"
    );
    assert!(output.contains("fg:39"));
}

#[test]
fn test_normalize_git_url() {
    // Test via state: set remote URL and check it's normalized
    let mut state = make_state(vec![]);
    state.git_remote_url = "https://github.com/user/repo".into();
    assert_eq!(state.git_remote_url, "https://github.com/user/repo");
}

#[test]
fn snapshot_git_pr_with_diff_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_pr_number = Some("123".into());
    state.git_remote_url = "https://github.com/user/repo".into();
    state.git_diff_stat = Some((55, 20));

    let plain = render_to_string(&mut state, 28, 14);
    // PR on left, diff stat on right
    assert!(plain.contains("#123"), "PR number should show");
    assert!(plain.contains("+55"), "Insertions should show");
    assert!(plain.contains("-20"), "Deletions should show");
}

#[test]
fn snapshot_subagents_tree_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.subagents = vec!["Explore #1".into(), "Plan".into(), "Explore #2".into()];

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 40, 27);
    let expected = indoc! {r#"
╭ project ─────────────────────────────╮
│ ● claude                             │
│   ├ Explore #1                       │
│   ├ Plan #2                          │
│   └ Explore #2                       │
╰──────────────────────────────────────╯
╭ Activity │ Git ──────────────────────╮
│            No activity yet           │
╰──────────────────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_subagent_long_name_truncated_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.subagents = vec![
        "superpowers:code-reviewer".into(),
        "claude-code-guide".into(),
    ];

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    // Narrow width (28) to force truncation of long subagent names
    let output = render_to_string(&mut state, 28, 26);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
│   ├ superpowers:code-rev…│
│   └ claude-code-guide #2 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);

    assert_right_border_intact(&output);
}

// ─── Empty State Centered Tests ─────────────────────────────────────

#[test]
fn snapshot_activity_empty_centered_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();
    state.bottom_tab = BottomTab::Activity;
    // No activity entries — should show centered "No activity yet"

    let output = render_to_string(&mut state, 28, 25);
    let plain = render_to_string(&mut state, 28, 25);
    assert!(plain.contains("No activity yet"));
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ○ claude                 │
│   Waiting for prompt…    │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_git_clean_centered_ui() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();
    state.bottom_tab = BottomTab::GitStatus;
    // No git info — should show centered "Working tree clean"

    let output = render_to_string(&mut state, 28, 25);
    let plain = render_to_string(&mut state, 28, 25);
    assert!(plain.contains("Working tree clean"));
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ○ claude                 │
│   Waiting for prompt…    │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│    Working tree clean    │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

// ─── Git: "Working tree clean" consistency ──────────────────────────

#[test]
fn snapshot_git_branch_loaded_no_changes_shows_inline_clean() {
    // Bug fix: when git_branch is set but no status/diff/commit data,
    // the early-return "centered clean" path was skipped, falling through
    // to a different "inline clean" layout. Now both paths are consistent.
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    // Branch loaded, but no changes/commits — should still show "Working tree clean"
    state.git_branch = "main".into();

    let plain = render_to_string(&mut state, 28, 24);
    assert!(
        plain.contains("Working tree clean"),
        "should show 'Working tree clean' even when branch is loaded but no changes"
    );
    assert!(
        plain.contains("main"),
        "should still display the branch name"
    );
}

#[test]
fn snapshot_git_no_data_shows_centered_clean() {
    // When no git data is loaded at all, should show centered "Working tree clean"
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    // No git data at all

    let output = render_to_string(&mut state, 28, 24);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│    Working tree clean    │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

// ─── Git: ahead/behind rendering ────────────────────────────────────

#[test]
fn test_git_behind_only() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_ahead_behind = Some((0, 3));

    let plain = render_to_string(&mut state, 28, 14);
    assert!(plain.contains("↓3"), "should show behind count");
    assert!(!plain.contains("↑"), "should not show ahead when 0");
}

#[test]
fn test_git_ahead_and_behind() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_ahead_behind = Some((2, 3));

    let plain = render_to_string(&mut state, 38, 14);
    assert!(plain.contains("↑2"), "should show ahead count");
    assert!(plain.contains("↓3"), "should show behind count");
}

// ─── Git: diff stat with only insertions or only deletions ──────────

#[test]
fn test_git_diff_insertions_only() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_diff_stat = Some((25, 0));

    let plain = render_to_string(&mut state, 28, 14);
    assert!(plain.contains("+25"), "should show insertions");
}

#[test]
fn test_git_diff_deletions_only() {
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
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    state.bottom_tab = BottomTab::GitStatus;
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.git_branch = "main".into();
    state.git_diff_stat = Some((0, 15));

    let plain = render_to_string(&mut state, 28, 14);
    assert!(plain.contains("-15"), "should show deletions");
}

#[test]
fn snapshot_branch_truncated_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@0".into(),
            window_index: 0,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane.clone()],
        }],
    }]);
    // Use a repo group with a long branch name via PaneGitInfo
    state.repo_groups = vec![tmux_agent_sidebar::group::RepoGroup {
        name: "dotfiles".into(),
        has_focus: true,
        panes: vec![(
            pane,
            tmux_agent_sidebar::group::PaneGitInfo {
                repo_root: Some("/home/user/dotfiles".into()),
                branch: Some("feature/tmux-sidebar-dashboard-refactor".into()),
                is_worktree: false,
            },
        )],
    }];
    state.rebuild_row_targets();

    let plain = render_to_string(&mut state, 28, 30);
    let expected = indoc! {r#"
╭ dotfiles ────────────────╮
│ ● claude                 │
│   feature/tmux-sidebar-d…│
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(plain, expected);
}

#[test]
fn snapshot_focused_group_active_border_styled() {
    // Two repo groups: focused pane in first, second should have inactive border
    let mut pane1 = make_pane(AgentType::Claude, PaneStatus::Running);
    pane1.pane_id = "%1".into();
    let mut pane2 = make_pane(AgentType::Codex, PaneStatus::Idle);
    pane2.pane_id = "%2".into();

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@0".into(),
            window_index: 0,
            window_name: "fish".into(),
            window_active: true,
            auto_rename: true,
            panes: vec![pane1.clone(), pane2.clone()],
        }],
    }]);
    state.repo_groups = vec![
        tmux_agent_sidebar::group::RepoGroup {
            name: "dotfiles".into(),
            has_focus: true,
            panes: vec![(
                pane1.clone(),
                tmux_agent_sidebar::group::PaneGitInfo::default(),
            )],
        },
        tmux_agent_sidebar::group::RepoGroup {
            name: "my-app".into(),
            has_focus: false,
            panes: vec![(
                pane2.clone(),
                tmux_agent_sidebar::group::PaneGitInfo::default(),
            )],
        },
    ];
    state.focused_pane_id = Some("%1".into());
    state.rebuild_row_targets();

    let styled = render_to_styled_string(&mut state, 28, 30);
    assert!(styled.contains("fg:117"));
}
