#[allow(dead_code, unused_imports)]
mod test_helpers;

use indoc::indoc;
use test_helpers::*;
use tmux_agent_sidebar::activity::{ActivityEntry, TaskProgress, TaskStatus};
use tmux_agent_sidebar::group::PaneGitInfo;
use tmux_agent_sidebar::state::Focus;
use tmux_agent_sidebar::tmux::{
    AgentType, PaneInfo, PaneStatus, PermissionMode, SessionInfo, WindowInfo,
};

// ─── UI Snapshot Tests ─────────────────────────────────────────────

#[test]
fn snapshot_single_agent_idle_ui() {
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

    let output = render_to_string(&mut state, 28, 25);
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
fn snapshot_single_agent_running_with_elapsed() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.started_at = Some(FIXED_NOW - 125); // 2m5s ago

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "dotfiles".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("dotfiles", vec![pane])];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ dotfiles ────────────────╮
│ ● claude             2m5s│
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn running_spinner_different_frame() {
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
    state.spinner_frame = 0;

    let output = render_to_string(&mut state, 28, 25);
    assert!(output.contains("●"));
    assert!(output.contains("claude"));
}

#[test]
fn snapshot_agent_with_prompt_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    pane.prompt = "fix the bug".into();

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

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ○ claude                 │
│   fix the bug            │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_agent_with_japanese_prompt_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.prompt = "これって今1時間経っているけど、起動して確認しても問題ない？".into();

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

    let output = render_to_string(&mut state, 28, 27);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
│   こ れ っ て 今 1時 間 経 っ て い │
│   る け ど 、 起 動 し て 確 認 し  │
│   て も 問 題 な い ？          │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_two_agents_same_window_ui() {
    let pane1 = PaneInfo {
        pane_id: "%1".into(),
        pane_active: true,
        status: PaneStatus::Running,
        attention: false,
        agent: AgentType::Claude,
        pane_name: String::new(),
        path: "/home/user/project".into(),
        command: "fish".into(),
        role: String::new(),
        prompt: "fix the bug".into(),
        started_at: None,
        wait_reason: String::new(),
        permission_mode: tmux_agent_sidebar::tmux::PermissionMode::Default,
        subagents: vec![],
        pane_pid: None,
    };
    let pane2 = PaneInfo {
        pane_id: "%2".into(),
        pane_active: false,
        status: PaneStatus::Idle,
        attention: false,
        agent: AgentType::Codex,
        pane_name: String::new(),
        path: "/home/user/project".into(),
        command: "fish".into(),
        role: String::new(),
        prompt: String::new(),
        started_at: None,
        wait_reason: String::new(),
        permission_mode: tmux_agent_sidebar::tmux::PermissionMode::Default,
        subagents: vec![],
        pane_pid: None,
    };

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "project".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane1.clone(), pane2.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane1, pane2])];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
│   fix the bug            │
│ ──────────────────────── │
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_two_windows_ui() {
    let pane1 = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut pane2 = make_pane(AgentType::Codex, PaneStatus::Idle);
    pane2.pane_id = "%2".into();
    pane2.pane_active = false;

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![
            WindowInfo {
                window_id: "@1".into(),
                window_index: 1,
                window_name: "project-a".into(),
                window_active: true,
                auto_rename: false,
                panes: vec![pane1.clone()],
            },
            WindowInfo {
                window_id: "@2".into(),
                window_index: 2,
                window_name: "project-b".into(),
                window_active: false,
                auto_rename: false,
                panes: vec![pane2.clone()],
            },
        ],
    }]);
    // Two different windows → two repo groups
    let mut group1 = make_repo_group("project-a", vec![pane1]);
    group1.has_focus = true;
    let mut group2 = make_repo_group("project-b", vec![pane2]);
    group2.has_focus = false;
    state.repo_groups = vec![group1, group2];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project-a ───────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ project-b ───────────────╮
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_multi_session_ui() {
    let pane1 = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut pane2 = make_pane(AgentType::Codex, PaneStatus::Idle);
    pane2.pane_id = "%2".into();
    pane2.pane_active = false;

    let mut state = make_state(vec![
        SessionInfo {
            session_name: "main".into(),
            attached: true,
            windows: vec![WindowInfo {
                window_id: "@1".into(),
                window_index: 1,
                window_name: "dotfiles".into(),
                window_active: true,
                auto_rename: false,
                panes: vec![pane1.clone()],
            }],
        },
        SessionInfo {
            session_name: "work".into(),
            attached: false,
            windows: vec![WindowInfo {
                window_id: "@2".into(),
                window_index: 1,
                window_name: "api".into(),
                window_active: false,
                auto_rename: false,
                panes: vec![pane2.clone()],
            }],
        },
    ]);
    // Multi-session → two repo groups (sessions don't matter for rendering)
    let mut group1 = make_repo_group("dotfiles", vec![pane1]);
    group1.has_focus = true;
    let mut group2 = make_repo_group("api", vec![pane2]);
    group2.has_focus = false;
    state.repo_groups = vec![group1, group2];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ dotfiles ────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ api ─────────────────────╮
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_wait_reason_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Waiting);
    pane.wait_reason = "permission_prompt".into();

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

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ◐ claude                 │
│   permission required    │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_auto_rename_window_title_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Idle);

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "fish".into(),
            window_active: true,
            auto_rename: true,
            panes: vec![pane.clone()],
        }],
    }]);
    // auto_rename=true: box title comes from RepoGroup.name (path basename = "project")
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 28, 25);
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
fn snapshot_no_sessions_ui() {
    let mut state = make_state(vec![]);
    let output = render_to_string(&mut state, 28, 25);
    assert_eq!(output, "No agent panes found");
}

#[test]
fn snapshot_activity_log_ui() {
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

    state.activity_entries = vec![
        ActivityEntry {
            timestamp: "10:32".into(),
            tool: "Edit".into(),
            label: "src/main.rs".into(),
        },
        ActivityEntry {
            timestamp: "10:31".into(),
            tool: "Bash".into(),
            label: "cargo build".into(),
        },
        ActivityEntry {
            timestamp: "10:30".into(),
            tool: "Read".into(),
            label: "Cargo.toml".into(),
        },
    ];

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│10:32                 Edit│
│  src/main.rs             │
│10:31                 Bash│
│  cargo build             │
│10:30                 Read│
│  Cargo.toml              │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_activity_log_long_label_ui() {
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

    state.activity_entries = vec![ActivityEntry {
        timestamp: "10:32".into(),
        tool: "Read".into(),
        label: "config/tmux-agent-sidebar-rs/src/very-long-filename.rs".into(),
    }];

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│10:32                 Read│
│  config/tmux-agent-sideba│
│  r-rs/src/very-long-filen│
│  ame.rs                  │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_prompt_wrapping_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    pane.prompt =
        "Please fix the authentication bug in the login flow that causes users to be logged out"
            .into();

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

    let output = render_to_string(&mut state, 28, 27);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ○ claude                 │
│   Please fix the         │
│   authentication bug in  │
│   the login flow that ca…│
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_selected_unfocused_ui() {
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
    state.sidebar_focused = false;

    let output = render_to_string(&mut state, 28, 25);
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
fn snapshot_error_state_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Error);
    pane.prompt = "something broke".into();

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

    let output = render_to_string(&mut state, 28, 25);
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ✕ claude                 │
│   something broke        │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_narrow_width_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    pane.prompt = "hello world".into();

    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "p".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane.clone()],
        }],
    }]);
    state.repo_groups = vec![make_repo_group("project", vec![pane])];
    state.rebuild_row_targets();

    let output = render_to_string(&mut state, 18, 25);
    let expected = indoc! {r#"
╭ project ───────╮
│ ○ claude       │
│   hello world  │
╰────────────────╯
╭ Activity │ Git ╮
│ No activity yet│
╰────────────────╯"#};
    assert_eq!(output, expected);
}

/// Create a state with a dummy session so draw() doesn't show "No agent panes found"
fn make_state_with_groups(
    groups: Vec<tmux_agent_sidebar::group::RepoGroup>,
) -> tmux_agent_sidebar::state::AppState {
    let pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    let mut state = make_state(vec![SessionInfo {
        session_name: "main".into(),
        attached: true,
        windows: vec![WindowInfo {
            window_id: "@1".into(),
            window_index: 1,
            window_name: "dummy".into(),
            window_active: true,
            auto_rename: false,
            panes: vec![pane],
        }],
    }]);
    state.repo_groups = groups;
    state.rebuild_row_targets();
    state
}

// ─── Worktree Branch Display ──────────────────────────────────────

#[test]
fn snapshot_worktree_branch_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.prompt = "fix bug".into();
    let git_info = PaneGitInfo {
        repo_root: Some("/home/user/project".into()),
        branch: Some("feature/sidebar".into()),
        is_worktree: true,
    };
    let mut state = make_state_with_groups(vec![tmux_agent_sidebar::group::RepoGroup {
        name: "project".into(),
        has_focus: true,
        panes: vec![(pane, git_info)],
    }]);

    let output = render_to_string(&mut state, 28, 26);
    assert!(
        output.contains("+ feature/sidebar"),
        "worktree should show '+ ' prefix before branch name"
    );
    let expected = indoc! {r#"
╭ project ─────────────────╮
│ ● claude                 │
│   + feature/sidebar      │
│   fix bug                │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

#[test]
fn snapshot_worktree_long_branch_truncated_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    let git_info = PaneGitInfo {
        repo_root: Some("/home/user/project".into()),
        branch: Some("feature/very-long-branch-name-that-overflows".into()),
        is_worktree: true,
    };
    let mut state = make_state_with_groups(vec![tmux_agent_sidebar::group::RepoGroup {
        name: "project".into(),
        has_focus: true,
        panes: vec![(pane, git_info)],
    }]);

    let output = render_to_string(&mut state, 28, 25);
    assert!(
        output.contains("+ feature/"),
        "worktree marker should appear even when truncated"
    );
    assert!(
        output.contains("…"),
        "long worktree branch should be truncated with ellipsis"
    );
}

// ─── Task Progress Variations ─────────────────────────────────────

#[test]
fn snapshot_task_progress_partial_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.prompt = "working".into();
    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);
    state.pane_task_progress.insert(
        "%1".into(),
        TaskProgress {
            tasks: vec![
                ("Task A".into(), TaskStatus::Completed),
                ("Task B".into(), TaskStatus::InProgress),
                ("Task C".into(), TaskStatus::Pending),
            ],
        },
    );

    let output = render_to_string(&mut state, 28, 25);
    assert!(
        output.contains("✔◼◻"),
        "should show completed/in-progress/pending icons"
    );
    assert!(output.contains("1/3"), "should show 1 of 3 completed");
}

#[test]
fn snapshot_task_progress_all_completed_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);
    state.pane_task_progress.insert(
        "%1".into(),
        TaskProgress {
            tasks: vec![
                ("A".into(), TaskStatus::Completed),
                ("B".into(), TaskStatus::Completed),
            ],
        },
    );

    let output = render_to_string(&mut state, 28, 25);
    assert!(output.contains("✔✔"), "should show all completed icons");
    assert!(output.contains("2/2"), "should show 2 of 2 completed");
}

#[test]
fn snapshot_task_progress_all_pending_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);
    state.pane_task_progress.insert(
        "%1".into(),
        TaskProgress {
            tasks: vec![
                ("A".into(), TaskStatus::Pending),
                ("B".into(), TaskStatus::Pending),
                ("C".into(), TaskStatus::Pending),
            ],
        },
    );

    let output = render_to_string(&mut state, 28, 25);
    assert!(output.contains("◻◻◻"), "should show all pending icons");
    assert!(output.contains("0/3"), "should show 0 of 3 completed");
}

// ─── Combined Elements ────────────────────────────────────────────

#[test]
fn snapshot_all_elements_combined_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Waiting);
    pane.prompt = "fixing the bug".into();
    pane.wait_reason = "permission_prompt".into();
    pane.subagents = vec!["Explore".into(), "Plan".into()];
    pane.permission_mode = PermissionMode::Auto;

    let git_info = PaneGitInfo {
        repo_root: Some("/home/user/project".into()),
        branch: Some("main".into()),
        is_worktree: false,
    };

    let mut state = make_state_with_groups(vec![tmux_agent_sidebar::group::RepoGroup {
        name: "project".into(),
        has_focus: true,
        panes: vec![(pane, git_info)],
    }]);
    state.pane_task_progress.insert(
        "%1".into(),
        TaskProgress {
            tasks: vec![
                ("A".into(), TaskStatus::Completed),
                ("B".into(), TaskStatus::InProgress),
            ],
        },
    );

    let output = render_to_string(&mut state, 30, 32);
    assert!(output.contains("claude auto"), "should show Auto badge");
    assert!(output.contains("main"), "should show branch");
    assert!(output.contains("✔◼"), "should show task progress");
    assert!(output.contains("├ "), "should show subagent tree");
    assert!(output.contains("└ "), "should show last subagent");
    assert!(
        output.contains("permission required"),
        "should show wait reason"
    );
    assert!(output.contains("fixing the bug"), "should show prompt");
    let expected = indoc! {r#"
╭ project ───────────────────╮
│ ◐ claude auto              │
│   main                     │
│   ✔◼ 1/2                   │
│   ├ Explore #1             │
│   └ Plan #2                │
│   permission required      │
│   fixing the bug           │
╰────────────────────────────╯
╭ Activity │ Git ────────────╮
│       No activity yet      │
╰────────────────────────────╯"#};
    assert_eq!(output, expected);
}

// ─── Response Display ─────────────────────────────────────────────

#[test]
fn snapshot_response_japanese_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Idle);
    pane.prompt = "\u{276f}\u{a0}修正が完了しました。テストも全て通っています。".into();
    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    let output = render_to_string(&mut state, 30, 27);
    assert!(output.contains("❯"), "should show response arrow");
    let expected = indoc! {r#"
╭ project ───────────────────╮
│ ○ claude                   │
│   ❯ 修 正 が 完 了 し ま し た 。 テ  │
│     ス ト も 全 て 通 っ て い ま す  │
│     。                      │
╰────────────────────────────╯
╭ Activity │ Git ────────────╮
│       No activity yet      │
╰────────────────────────────╯"#};
    assert_eq!(output, expected);
}

// ─── Three Groups with Focus ─────────────────────────────────────

#[test]
fn snapshot_three_groups_middle_focused_ui() {
    let pane1 = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut pane2 = make_pane(AgentType::Codex, PaneStatus::Idle);
    pane2.pane_id = "%2".into();
    pane2.pane_active = false;
    let mut pane3 = make_pane(AgentType::Claude, PaneStatus::Idle);
    pane3.pane_id = "%3".into();
    pane3.pane_active = false;

    let mut group1 = make_repo_group("repo-a", vec![pane1]);
    group1.has_focus = false;
    let mut group2 = make_repo_group("repo-b", vec![pane2]);
    group2.has_focus = false;
    let mut group3 = make_repo_group("repo-c", vec![pane3]);
    group3.has_focus = false;
    let mut state = make_state_with_groups(vec![group1, group2, group3]);
    state.focused_pane_id = Some("%2".into());

    let output = render_to_string(&mut state, 28, 32);
    assert!(output.contains("repo-a"), "should show first group");
    assert!(output.contains("repo-b"), "should show second group");
    assert!(output.contains("repo-c"), "should show third group");
    let expected = indoc! {r#"
╭ repo-a ──────────────────╮
│ ● claude                 │
╰──────────────────────────╯
╭ repo-b ──────────────────╮
│ ○ codex                  │
│   Waiting for prompt…    │
╰──────────────────────────╯
╭ repo-c ──────────────────╮
│ ○ claude                 │
│   Waiting for prompt…    │
╰──────────────────────────╯
╭ Activity │ Git ──────────╮
│      No activity yet     │
╰──────────────────────────╯"#};
    assert_eq!(output, expected);
}

// ─── PermissionMode Badges ────────────────────────────────────────

#[test]
fn snapshot_bypass_all_badge_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.permission_mode = PermissionMode::BypassPermissions;

    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    let output = render_to_string(&mut state, 28, 25);
    assert!(
        output.contains("claude !"),
        "BypassPermissions should show ! badge"
    );
}

#[test]
fn snapshot_full_auto_badge_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.permission_mode = PermissionMode::Auto;

    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    let output = render_to_string(&mut state, 28, 25);
    assert!(
        output.contains("claude auto"),
        "Auto should show auto badge"
    );
}

// ─── Multiple Wait Reasons ────────────────────────────────────────

#[test]
fn snapshot_wait_reason_elicitation_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Waiting);
    pane.wait_reason = "elicitation_dialog".into();

    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    let output = render_to_string(&mut state, 28, 25);
    assert!(
        output.contains("waiting for selection"),
        "elicitation should show selection label"
    );
}

#[test]
fn snapshot_wait_reason_unknown_ui() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Waiting);
    pane.wait_reason = "some_future_reason".into();

    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    let output = render_to_string(&mut state, 28, 25);
    assert!(
        output.contains("some_future_reason"),
        "unknown wait reason should show raw value"
    );
}

// ─── Activity Log Tool Types ──────────────────────────────────────

#[test]
fn snapshot_activity_all_tool_types_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    state.activity_entries = vec![
        ActivityEntry {
            timestamp: "10:07".into(),
            tool: "Agent".into(),
            label: "Explore codebase".into(),
        },
        ActivityEntry {
            timestamp: "10:06".into(),
            tool: "Skill".into(),
            label: "commit".into(),
        },
        ActivityEntry {
            timestamp: "10:05".into(),
            tool: "ToolSearch".into(),
            label: "select:Read".into(),
        },
        ActivityEntry {
            timestamp: "10:04".into(),
            tool: "TaskCreate".into(),
            label: "#1 Fix bug".into(),
        },
        ActivityEntry {
            timestamp: "10:03".into(),
            tool: "WebFetch".into(),
            label: "docs.rs/ratatui".into(),
        },
        ActivityEntry {
            timestamp: "10:02".into(),
            tool: "Grep".into(),
            label: "run_git".into(),
        },
        ActivityEntry {
            timestamp: "10:01".into(),
            tool: "Write".into(),
            label: "new_file.rs".into(),
        },
    ];

    let output = render_to_string(&mut state, 28, 25);
    assert!(output.contains("Agent"), "should show Agent tool");
    assert!(output.contains("Skill"), "should show Skill tool");
    assert!(output.contains("ToolSearch"), "should show ToolSearch tool");
    assert!(output.contains("TaskCreate"), "should show TaskCreate tool");
}

// ─── Focus Transitions ───────────────────────────────────────────

#[test]
fn snapshot_focus_activity_log_ui() {
    let pane = make_pane(AgentType::Claude, PaneStatus::Running);
    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);
    state.focus = Focus::ActivityLog;
    state.sidebar_focused = true;
    state.activity_entries = vec![ActivityEntry {
        timestamp: "10:00".into(),
        tool: "Read".into(),
        label: "file.rs".into(),
    }];

    let output = render_to_string(&mut state, 28, 25);
    // Agent should NOT have selection background when focus is on activity
    assert!(output.contains("claude"), "agent should still be visible");
}

// ─── Right Border Integrity ──────────────────────────────────────

#[test]
fn right_border_narrow_width_with_badge() {
    let mut pane = make_pane(AgentType::Claude, PaneStatus::Running);
    pane.started_at = Some(FIXED_NOW - 7200); // 2h ago
    pane.permission_mode = PermissionMode::BypassPermissions;
    pane.prompt = "fix the issue".into();

    let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

    let output = render_to_string(&mut state, 22, 25);
    assert!(
        output.contains("!"),
        "badge should remain visible at narrow width"
    );
    assert_right_border_intact(&output);
}

#[test]
fn right_border_all_permission_modes_and_agents() {
    let modes_and_badges: &[(PermissionMode, &str)] = &[
        (PermissionMode::Default, ""),
        (PermissionMode::Auto, "auto"),
        (PermissionMode::Plan, "plan"),
        (PermissionMode::AcceptEdits, "edit"),
        (PermissionMode::BypassPermissions, "!"),
    ];
    let agents = [AgentType::Claude, AgentType::Codex];
    let now = FIXED_NOW;

    for agent in &agents {
        for (mode, expected_badge) in modes_and_badges {
            let mut pane = make_pane(agent.clone(), PaneStatus::Running);
            pane.permission_mode = mode.clone();
            pane.started_at = Some(now - 5432); // ~1h30m

            let mut state = make_state_with_groups(vec![make_repo_group("project", vec![pane])]);

            let output = render_to_string(&mut state, 28, 25);
            assert_right_border_intact(&output);
            if !expected_badge.is_empty() {
                assert!(
                    output.contains(expected_badge),
                    "{:?} {:?} should show badge {:?}",
                    agent,
                    mode,
                    expected_badge,
                );
            }
        }
    }
}
