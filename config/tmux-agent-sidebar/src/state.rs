use std::collections::HashMap;

use crate::activity::{ActivityEntry, TaskProgress};
use crate::tmux::{self, SessionInfo};
use crate::ui::colors::ColorTheme;

mod refresh;
mod tab;
#[cfg(test)]
pub(crate) use refresh::{TaskProgressDecision, classify_task_progress};

#[derive(Debug, Clone, PartialEq)]
pub enum Focus {
    Agents,
    ActivityLog,
}

#[derive(Debug, Clone, PartialEq)]
pub enum BottomTab {
    Activity,
    GitStatus,
}

#[derive(Debug, Clone)]
pub struct RowTarget {
    pub pane_id: String,
}

#[derive(Debug, Clone, Default)]
pub struct ScrollState {
    pub offset: usize,
    pub total_lines: usize,
    pub visible_height: usize,
}

impl ScrollState {
    pub fn scroll(&mut self, delta: isize) {
        let max = self.total_lines.saturating_sub(self.visible_height);
        let next = self.offset as isize + delta;
        self.offset = next.max(0).min(max as isize) as usize;
    }
}

pub struct AppState {
    pub now: u64,
    pub sessions: Vec<SessionInfo>,
    pub repo_groups: Vec<crate::group::RepoGroup>,
    pub sidebar_focused: bool,
    pub focus: Focus,
    pub spinner_frame: usize,
    pub selected_agent_row: usize,
    pub agent_row_targets: Vec<RowTarget>,
    pub activity_entries: Vec<ActivityEntry>,
    pub activity_scroll: ScrollState,
    pub focused_pane_id: Option<String>,
    pub tmux_pane: String,
    pub activity_max_entries: usize,
    pub line_to_row: Vec<Option<usize>>,
    pub agents_scroll: ScrollState,
    pub theme: ColorTheme,
    pub bottom_tab: BottomTab,
    pub git_diff_stat: Option<(usize, usize)>,
    pub git_branch: String,
    pub git_ahead_behind: Option<(usize, usize)>,
    pub git_staged_files: Vec<crate::git::GitFileEntry>,
    pub git_unstaged_files: Vec<crate::git::GitFileEntry>,
    pub git_untracked_files: Vec<String>,
    pub git_changed_file_count: usize,
    pub git_remote_url: String,
    pub git_pr_number: Option<String>,
    pub git_scroll: ScrollState,
    pub pane_task_progress: HashMap<String, TaskProgress>,
    pub pane_task_dismissed: HashMap<String, usize>,
    /// Tracks when each pane first became inactive (epoch seconds).
    /// Used to debounce task progress dismissal — the agent status can
    /// briefly flicker to idle (e.g. during system prompt delivery),
    /// so we wait a grace period before actually hiding task progress.
    pub pane_inactive_since: HashMap<String, u64>,
    /// Agent pane IDs that have already been seen. Used to detect new agent
    /// launches and auto-switch the bottom tab to Activity only once.
    pub seen_agent_panes: std::collections::HashSet<String>,
    /// Per-pane bottom tab preference. Saved when focus leaves a pane,
    /// restored when focus returns.
    pub pane_tab_prefs: HashMap<String, BottomTab>,
    /// Previous focused pane ID, used to detect focus changes.
    pub prev_focused_pane_id: Option<String>,
}

impl AppState {
    pub fn new(tmux_pane: String) -> Self {
        Self {
            now: 0,
            sessions: vec![],
            repo_groups: vec![],
            sidebar_focused: false,
            focus: Focus::Agents,
            spinner_frame: 0,
            selected_agent_row: 0,
            agent_row_targets: vec![],
            activity_entries: vec![],
            activity_scroll: ScrollState::default(),
            focused_pane_id: None,
            tmux_pane,
            activity_max_entries: 50,
            line_to_row: vec![],
            agents_scroll: ScrollState::default(),
            theme: ColorTheme::default(),
            bottom_tab: BottomTab::Activity,
            git_diff_stat: None,
            git_branch: String::new(),
            git_ahead_behind: None,
            git_staged_files: vec![],
            git_unstaged_files: vec![],
            git_untracked_files: vec![],
            git_changed_file_count: 0,
            git_remote_url: String::new(),
            git_pr_number: None,
            git_scroll: ScrollState::default(),
            pane_task_progress: HashMap::new(),
            pane_task_dismissed: HashMap::new(),
            pane_inactive_since: HashMap::new(),
            seen_agent_panes: std::collections::HashSet::new(),
            pane_tab_prefs: HashMap::new(),
            prev_focused_pane_id: None,
        }
    }

    pub fn rebuild_row_targets(&mut self) {
        self.agent_row_targets.clear();
        for group in &self.repo_groups {
            for (pane, _) in &group.panes {
                self.agent_row_targets.push(RowTarget {
                    pane_id: pane.pane_id.clone(),
                });
            }
        }
        if self.selected_agent_row >= self.agent_row_targets.len()
            && !self.agent_row_targets.is_empty()
        {
            self.selected_agent_row = self.agent_row_targets.len() - 1;
        }
    }

    pub fn find_focused_pane(&mut self) {
        // Query tmux directly for the active pane, not through self.sessions
        // which only contains agent panes. This allows activity/git info to
        // be displayed even when the focused pane has no agent running.
        self.focused_pane_id =
            tmux::find_active_pane(&self.tmux_pane).map(|(id, _)| id);
    }


    /// Move agent selection. Returns true if moved, false if at boundary.
    pub fn move_agent_selection(&mut self, delta: isize) -> bool {
        if self.agent_row_targets.is_empty() {
            return false;
        }
        let len = self.agent_row_targets.len() as isize;
        let next = self.selected_agent_row as isize + delta;
        if next >= 0 && next < len {
            self.selected_agent_row = next as usize;
            true
        } else {
            false
        }
    }

    pub fn activate_selection(&self) {
        if let Some(target) = self.agent_row_targets.get(self.selected_agent_row) {
            tmux::select_pane(&target.pane_id);
        }
    }

    pub fn next_bottom_tab(&mut self) {
        self.bottom_tab = match self.bottom_tab {
            BottomTab::Activity => BottomTab::GitStatus,
            BottomTab::GitStatus => BottomTab::Activity,
        };
    }

    pub fn scroll_bottom(&mut self, delta: isize) {
        match self.bottom_tab {
            BottomTab::Activity => self.activity_scroll.scroll(delta),
            BottomTab::GitStatus => self.git_scroll.scroll(delta),
        }
    }

    /// Handle mouse scroll event, routing to agents or bottom panel based on Y position.
    pub fn handle_mouse_scroll(&mut self, row: u16, term_height: u16, bottom_panel_height: u16, delta: isize) {
        let bottom_start = term_height.saturating_sub(bottom_panel_height);
        if row >= bottom_start {
            self.scroll_bottom(delta);
        } else {
            self.agents_scroll.scroll(delta);
        }
    }

    pub fn apply_git_data(&mut self, data: crate::git::GitData) {
        self.git_diff_stat = data.diff_stat;
        self.git_branch = data.branch;
        self.git_ahead_behind = data.ahead_behind;
        self.git_staged_files = data.staged_files;
        self.git_unstaged_files = data.unstaged_files;
        self.git_untracked_files = data.untracked_files;
        self.git_changed_file_count = data.changed_file_count;
        self.git_remote_url = data.remote_url;
        self.git_pr_number = data.pr_number;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::activity::{TaskProgress, TaskStatus};
    use crate::group::{PaneGitInfo, RepoGroup};
    use crate::tmux::{AgentType, PaneInfo, PaneStatus, PermissionMode};
    use std::fs;

    fn test_pane(id: &str) -> PaneInfo {
        PaneInfo {
            pane_id: id.into(),
            pane_active: false,
            status: PaneStatus::Running,
            attention: false,
            agent: AgentType::Claude,
            path: "/tmp".into(),
            prompt: String::new(),
            prompt_is_response: false,
            started_at: None,
            wait_reason: String::new(),
            permission_mode: PermissionMode::Default,
            subagents: vec![],
            pane_pid: None,
        }
    }

    fn write_activity_log(pane_id: &str, contents: &str) -> String {
        let path = crate::activity::log_file_path(pane_id);
        fs::write(&path, contents).unwrap();
        path.to_string_lossy().into_owned()
    }

    #[test]
    fn rebuild_row_targets_from_repo_groups() {
        let mut state = AppState::new("%99".into());
        state.repo_groups = vec![
            RepoGroup {
                name: "dotfiles".into(),
                has_focus: true,
                panes: vec![
                    (test_pane("%1"), PaneGitInfo::default()),
                    (test_pane("%2"), PaneGitInfo::default()),
                ],
            },
            RepoGroup {
                name: "app".into(),
                has_focus: false,
                panes: vec![(test_pane("%3"), PaneGitInfo::default())],
            },
        ];
        state.rebuild_row_targets();

        assert_eq!(state.agent_row_targets.len(), 3);
        assert_eq!(state.agent_row_targets[0].pane_id, "%1");
        assert_eq!(state.agent_row_targets[1].pane_id, "%2");
        assert_eq!(state.agent_row_targets[2].pane_id, "%3");
    }

    #[test]
    fn selection_crosses_repo_groups() {
        let mut state = AppState::new("%99".into());
        state.repo_groups = vec![
            RepoGroup {
                name: "dotfiles".into(),
                has_focus: true,
                panes: vec![(test_pane("%1"), PaneGitInfo::default())],
            },
            RepoGroup {
                name: "app".into(),
                has_focus: false,
                panes: vec![(test_pane("%5"), PaneGitInfo::default())],
            },
        ];
        state.rebuild_row_targets();

        // Start at first group
        assert_eq!(state.selected_agent_row, 0);
        assert_eq!(state.agent_row_targets[0].pane_id, "%1");

        // Move to second group
        assert!(state.move_agent_selection(1));
        assert_eq!(state.selected_agent_row, 1);
        assert_eq!(state.agent_row_targets[1].pane_id, "%5");
    }

    #[test]
    fn task_progress_hides_when_all_completed() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%100".to_string();

        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane("%100"), PaneGitInfo::default())],
        }];

        let log_path = crate::activity::log_file_path(&pane_id);
        fs::write(
            &log_path,
            "10:00|TaskCreate|#1 A\n10:01|TaskCreate|#2 B\n10:02|TaskUpdate|completed #1\n10:03|TaskUpdate|completed #2\n",
        ).unwrap();

        state.refresh_task_progress();

        // All completed → hidden immediately
        assert!(state.pane_task_progress.get(&pane_id).is_none());
        // Dismissed count should be recorded
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&2));

        // Calling refresh again should still be hidden (no flicker)
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_none());

        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn task_progress_reshows_when_new_tasks_added() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%101".to_string();

        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane("%101"), PaneGitInfo::default())],
        }];

        // First: 1 task, completed → dismissed
        let log_path = crate::activity::log_file_path(&pane_id);
        fs::write(
            &log_path,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|completed #1\n",
        )
        .unwrap();
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_none());

        // Now add a new in-progress task → should re-show
        fs::write(
            &log_path,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|completed #1\n10:02|TaskCreate|#2 B\n10:03|TaskUpdate|in_progress #2\n",
        ).unwrap();
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());

        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn classify_task_progress_empty_clears() {
        let progress = TaskProgress { tasks: vec![] };
        assert_eq!(
            classify_task_progress(&progress, None),
            TaskProgressDecision::Clear
        );
    }

    #[test]
    fn classify_task_progress_in_progress_shows() {
        let progress = TaskProgress {
            tasks: vec![
                ("A".into(), TaskStatus::Completed),
                ("B".into(), TaskStatus::InProgress),
            ],
        };
        assert_eq!(
            classify_task_progress(&progress, None),
            TaskProgressDecision::Show
        );
    }

    #[test]
    fn classify_task_progress_completed_dismisses_once() {
        let progress = TaskProgress {
            tasks: vec![
                ("A".into(), TaskStatus::Completed),
                ("B".into(), TaskStatus::Completed),
            ],
        };
        assert_eq!(
            classify_task_progress(&progress, None),
            TaskProgressDecision::Dismiss { total: 2 }
        );
        assert_eq!(
            classify_task_progress(&progress, Some(2)),
            TaskProgressDecision::Skip
        );
    }

    #[test]
    fn classify_task_progress_completed_with_different_dismissal_dismisses_again() {
        let progress = TaskProgress {
            tasks: vec![
                ("A".into(), TaskStatus::Completed),
                ("B".into(), TaskStatus::Completed),
            ],
        };
        assert_eq!(
            classify_task_progress(&progress, Some(1)),
            TaskProgressDecision::Dismiss { total: 2 }
        );
    }

    #[test]
    fn refresh_now_updates_current_time() {
        let mut state = AppState::new("%99".into());
        state.refresh_now();
        assert!(state.now > 0);
    }

    #[test]
    fn refresh_activity_log_reads_focused_pane() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%201";
        let log_path = crate::activity::log_file_path(pane_id);
        fs::write(&log_path, "10:00|Read|old\n10:01|Edit|new\n").unwrap();
        state.focused_pane_id = Some(pane_id.into());
        state.activity_max_entries = 50;

        state.refresh_activity_log();

        assert_eq!(state.activity_entries.len(), 2);
        assert_eq!(state.activity_entries[0].tool, "Edit");
        assert_eq!(state.activity_entries[0].label, "new");
        assert_eq!(state.activity_entries[1].tool, "Read");

        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_activity_log_clears_without_focus() {
        let mut state = AppState::new("%99".into());
        state.activity_entries = vec![crate::activity::ActivityEntry {
            timestamp: "10:00".into(),
            tool: "Read".into(),
            label: "keep?".into(),
        }];

        state.focused_pane_id = None;
        state.refresh_activity_log();

        assert!(state.activity_entries.is_empty());
    }

    #[test]
    fn refresh_task_progress_clears_empty_logs_and_dismissal() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%202".to_string();
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane(&pane_id), PaneGitInfo::default())],
        }];
        state.pane_task_progress.insert(
            pane_id.clone(),
            TaskProgress {
                tasks: vec![("stale".into(), TaskStatus::InProgress)],
            },
        );
        state.pane_task_dismissed.insert(pane_id.clone(), 1);

        state.refresh_task_progress();

        assert!(state.pane_task_progress.is_empty());
        assert!(state.pane_task_dismissed.is_empty());
    }

    #[test]
    fn refresh_task_progress_shows_in_progress_and_clears_dismissal() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%203".to_string();
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane(&pane_id), PaneGitInfo::default())],
        }];
        state.pane_task_dismissed.insert(pane_id.clone(), 1);
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|in_progress #1\n",
        );

        state.refresh_task_progress();

        assert_eq!(state.pane_task_dismissed.get(&pane_id), None);
        assert_eq!(
            state.pane_task_progress.get(&pane_id).map(|p| p.total()),
            Some(1)
        );
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_records_completed_dismissal() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%204".to_string();
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane(&pane_id), PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|completed #1\n",
        );

        state.refresh_task_progress();

        assert!(state.pane_task_progress.get(&pane_id).is_none());
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&1));
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_skips_already_dismissed_completed_tasks() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%205".to_string();
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane(&pane_id), PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|completed #1\n",
        );

        state.refresh_task_progress();
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&1));
        assert!(state.pane_task_progress.get(&pane_id).is_none());

        state.refresh_task_progress();
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&1));
        assert!(state.pane_task_progress.get(&pane_id).is_none());
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_drops_dismissals_for_inactive_panes() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%206".to_string();
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane(&pane_id), PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|completed #1\n",
        );
        state.refresh_task_progress();
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&1));

        // Pane removed — both dismissed and inactive_since should be cleaned up
        state.repo_groups.clear();
        state.pane_inactive_since
            .insert(pane_id.clone(), 100);
        state.refresh_task_progress();

        assert!(state.pane_task_dismissed.is_empty());
        assert!(state.pane_inactive_since.is_empty());
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_dismisses_incomplete_tasks_when_agent_idle() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%207".to_string();
        let mut pane = test_pane(&pane_id);
        pane.status = PaneStatus::Idle;
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(pane, PaneGitInfo::default())],
        }];
        // 5 out of 6 tasks completed — agent is idle so it won't update further
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskCreate|#2 B\n10:02|TaskCreate|#3 C\n10:03|TaskCreate|#4 D\n10:04|TaskCreate|#5 E\n10:05|TaskCreate|#6 F\n10:06|TaskUpdate|completed #1\n10:07|TaskUpdate|completed #2\n10:08|TaskUpdate|completed #3\n10:09|TaskUpdate|completed #4\n10:10|TaskUpdate|completed #5\n",
        );

        // First refresh: grace period starts, tasks still shown (not dismissed yet)
        state.now = 100;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());
        assert!(state.pane_inactive_since.contains_key(&pane_id));

        // After grace period (3s): should be dismissed
        state.now = 104;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_none());
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&6));
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_shows_incomplete_tasks_when_agent_running() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%208".to_string();
        // test_pane defaults to PaneStatus::Running
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(test_pane(&pane_id), PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskCreate|#2 B\n10:02|TaskUpdate|completed #1\n10:03|TaskUpdate|in_progress #2\n",
        );

        state.refresh_task_progress();

        // Agent is running, so incomplete tasks should still be shown
        assert!(state.pane_task_progress.get(&pane_id).is_some());
        assert_eq!(
            state.pane_task_progress.get(&pane_id).map(|p| p.total()),
            Some(2)
        );
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_dismisses_incomplete_tasks_when_agent_error() {
        let mut state = AppState::new("%99".into());
        let pane_id = "%209".to_string();
        let mut pane = test_pane(&pane_id);
        pane.status = PaneStatus::Error;
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(pane, PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|in_progress #1\n",
        );

        // First refresh: grace period starts, tasks still shown
        state.now = 100;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());

        // After grace period: agent errored out — dismiss incomplete tasks
        state.now = 104;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_none());
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&1));
        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_debounce_resets_when_agent_resumes() {
        // Simulates brief idle flicker: agent goes idle then returns to running
        // before the grace period expires — tasks should remain visible.
        let mut state = AppState::new("%99".into());
        let pane_id = "%210".to_string();
        let mut pane = test_pane(&pane_id);
        pane.status = PaneStatus::Idle;
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(pane, PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskCreate|#2 B\n10:02|TaskUpdate|completed #1\n",
        );

        // Agent is idle — grace timer starts, tasks still shown
        state.now = 100;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());
        assert!(state.pane_inactive_since.contains_key(&pane_id));

        // Agent returns to running before grace expires — timer resets
        let mut pane = test_pane(&pane_id);
        pane.status = PaneStatus::Running;
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(pane, PaneGitInfo::default())],
        }];
        state.now = 102;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());
        assert!(!state.pane_inactive_since.contains_key(&pane_id));

        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_debounce_exact_boundary() {
        // Grace period is 3 seconds. At exactly 3s the condition is >=,
        // so it should dismiss.
        let mut state = AppState::new("%99".into());
        let pane_id = "%211".to_string();
        let mut pane = test_pane(&pane_id);
        pane.status = PaneStatus::Idle;
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(pane, PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|in_progress #1\n",
        );

        // t=100: grace timer starts
        state.now = 100;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());

        // t=102 (2s elapsed): still within grace period — tasks shown
        state.now = 102;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_some());

        // t=103 (exactly 3s): grace expired (>= 3) — dismissed
        state.now = 103;
        state.refresh_task_progress();
        assert!(state.pane_task_progress.get(&pane_id).is_none());
        assert_eq!(state.pane_task_dismissed.get(&pane_id), Some(&1));

        fs::remove_file(&log_path).ok();
    }

    #[test]
    fn refresh_task_progress_waiting_does_not_start_debounce() {
        // Waiting is an active state — inactive timer should not be set.
        let mut state = AppState::new("%99".into());
        let pane_id = "%212".to_string();
        let mut pane = test_pane(&pane_id);
        pane.status = PaneStatus::Waiting;
        state.repo_groups = vec![RepoGroup {
            name: "test".into(),
            has_focus: true,
            panes: vec![(pane, PaneGitInfo::default())],
        }];
        let log_path = write_activity_log(
            &pane_id,
            "10:00|TaskCreate|#1 A\n10:01|TaskUpdate|in_progress #1\n",
        );

        state.now = 100;
        state.refresh_task_progress();

        // Tasks shown and no inactive timer started
        assert!(state.pane_task_progress.get(&pane_id).is_some());
        assert!(!state.pane_inactive_since.contains_key(&pane_id));

        fs::remove_file(&log_path).ok();
    }

    // ─── ScrollState unit tests ─────────────────────────────────────

    #[test]
    fn scroll_state_clamps_to_max() {
        let mut s = ScrollState {
            offset: 0,
            total_lines: 10,
            visible_height: 4,
        };
        s.scroll(100);
        assert_eq!(s.offset, 6); // max = 10 - 4
    }

    #[test]
    fn scroll_state_clamps_to_zero() {
        let mut s = ScrollState {
            offset: 3,
            total_lines: 10,
            visible_height: 4,
        };
        s.scroll(-100);
        assert_eq!(s.offset, 0);
    }

    #[test]
    fn scroll_state_noop_when_content_fits() {
        let mut s = ScrollState {
            offset: 0,
            total_lines: 3,
            visible_height: 5,
        };
        s.scroll(1);
        assert_eq!(s.offset, 0);
    }

    #[test]
    fn scroll_state_exact_fit_no_scroll() {
        let mut s = ScrollState {
            offset: 0,
            total_lines: 5,
            visible_height: 5,
        };
        s.scroll(1);
        assert_eq!(s.offset, 0);
    }

    #[test]
    fn scroll_state_incremental() {
        let mut s = ScrollState {
            offset: 0,
            total_lines: 10,
            visible_height: 4,
        };
        s.scroll(1);
        assert_eq!(s.offset, 1);
        s.scroll(2);
        assert_eq!(s.offset, 3);
        s.scroll(-1);
        assert_eq!(s.offset, 2);
    }

    // ─── apply_git_data tests ───────────────────────────────────────

    #[test]
    fn apply_git_data_copies_all_fields() {
        let mut state = AppState::new("%99".into());
        let data = crate::git::GitData {
            diff_stat: Some((10, 5)),
            branch: "feature/test".into(),
            ahead_behind: Some((2, 1)),
            staged_files: vec![crate::git::GitFileEntry {
                status: 'M',
                name: "lib.rs".into(),
                additions: 10,
                deletions: 5,
            }],
            unstaged_files: vec![],
            untracked_files: vec!["new.rs".into()],
            changed_file_count: 2,
            remote_url: "https://github.com/user/repo".into(),
            pr_number: Some("42".into()),
        };

        state.apply_git_data(data);

        assert_eq!(state.git_diff_stat, Some((10, 5)));
        assert_eq!(state.git_branch, "feature/test");
        assert_eq!(state.git_ahead_behind, Some((2, 1)));
        assert_eq!(state.git_staged_files.len(), 1);
        assert_eq!(state.git_staged_files[0].status, 'M');
        assert!(state.git_unstaged_files.is_empty());
        assert_eq!(state.git_untracked_files, vec!["new.rs"]);
        assert_eq!(state.git_changed_file_count, 2);
        assert_eq!(state.git_remote_url, "https://github.com/user/repo");
        assert_eq!(state.git_pr_number, Some("42".into()));
    }

    #[test]
    fn apply_git_data_with_defaults() {
        let mut state = AppState::new("%99".into());
        // Pre-fill some state
        state.git_branch = "old-branch".into();
        state.git_pr_number = Some("99".into());

        // Apply empty git data
        state.apply_git_data(crate::git::GitData::default());

        assert_eq!(state.git_diff_stat, None);
        assert!(state.git_branch.is_empty());
        assert_eq!(state.git_ahead_behind, None);
        assert!(state.git_staged_files.is_empty());
        assert!(state.git_unstaged_files.is_empty());
        assert!(state.git_untracked_files.is_empty());
        assert_eq!(state.git_changed_file_count, 0);
        assert!(state.git_remote_url.is_empty());
        assert_eq!(state.git_pr_number, None);
    }

    #[test]
    fn apply_session_snapshot_rebuilds_derived_state() {
        let mut state = AppState::new("%99".into());
        state.selected_agent_row = 3;

        let pane = test_pane("%1");
        let sessions = vec![SessionInfo {
            session_name: "main".into(),
            windows: vec![crate::tmux::WindowInfo {
                window_id: "@0".into(),
                window_name: "project".into(),
                window_active: true,
                auto_rename: false,
                panes: vec![pane],
            }],
        }];

        state.apply_session_snapshot(true, sessions);

        assert!(state.sidebar_focused);
        assert_eq!(state.sessions.len(), 1);
        assert_eq!(state.repo_groups.len(), 1);
        assert_eq!(state.agent_row_targets.len(), 1);
        assert_eq!(state.selected_agent_row, 0);
        // focused_pane_id is set by find_focused_pane() which queries tmux
        // directly, so we don't assert it here (tmux not available in tests).
    }

    // ─── auto_switch_tab tests are in state/tab.rs ────────────────

    // ─── next_bottom_tab / scroll_bottom tests ──────────────────────

    #[test]
    fn next_bottom_tab_toggles() {
        let mut state = AppState::new("%99".into());
        assert_eq!(state.bottom_tab, BottomTab::Activity);
        state.next_bottom_tab();
        assert_eq!(state.bottom_tab, BottomTab::GitStatus);
        state.next_bottom_tab();
        assert_eq!(state.bottom_tab, BottomTab::Activity);
    }

    #[test]
    fn scroll_bottom_dispatches_to_activity() {
        let mut state = AppState::new("%99".into());
        state.bottom_tab = BottomTab::Activity;
        state.activity_scroll = ScrollState {
            offset: 0,
            total_lines: 10,
            visible_height: 3,
        };

        state.scroll_bottom(2);
        assert_eq!(state.activity_scroll.offset, 2);
        assert_eq!(state.git_scroll.offset, 0);
    }

    #[test]
    fn scroll_bottom_dispatches_to_git() {
        let mut state = AppState::new("%99".into());
        state.bottom_tab = BottomTab::GitStatus;
        state.git_scroll = ScrollState {
            offset: 0,
            total_lines: 10,
            visible_height: 3,
        };

        state.scroll_bottom(2);
        assert_eq!(state.git_scroll.offset, 2);
        assert_eq!(state.activity_scroll.offset, 0);
    }

    // ─── handle_mouse_scroll tests ────────────────────────────────────

    #[test]
    fn mouse_scroll_in_bottom_panel_scrolls_activity() {
        let mut state = AppState::new("%99".into());
        state.bottom_tab = BottomTab::Activity;
        state.activity_scroll = ScrollState {
            offset: 0,
            total_lines: 30,
            visible_height: 10,
        };
        // term_height=50, bottom_panel=20 → bottom starts at row 30
        // mouse at row 35 → in bottom panel
        state.handle_mouse_scroll(35, 50, 20, 3);
        assert_eq!(state.activity_scroll.offset, 3);
        assert_eq!(state.agents_scroll.offset, 0);
    }

    #[test]
    fn mouse_scroll_in_agents_panel_scrolls_agents() {
        let mut state = AppState::new("%99".into());
        state.agents_scroll = ScrollState {
            offset: 0,
            total_lines: 40,
            visible_height: 20,
        };
        // term_height=50, bottom_panel=20 → bottom starts at row 30
        // mouse at row 10 → in agents panel
        state.handle_mouse_scroll(10, 50, 20, 3);
        assert_eq!(state.agents_scroll.offset, 3);
        assert_eq!(state.activity_scroll.offset, 0);
    }

    #[test]
    fn mouse_scroll_up_in_agents_panel() {
        let mut state = AppState::new("%99".into());
        state.agents_scroll = ScrollState {
            offset: 5,
            total_lines: 40,
            visible_height: 20,
        };
        state.handle_mouse_scroll(10, 50, 20, -3);
        assert_eq!(state.agents_scroll.offset, 2);
    }

    #[test]
    fn mouse_scroll_at_boundary_row_goes_to_bottom() {
        let mut state = AppState::new("%99".into());
        state.bottom_tab = BottomTab::GitStatus;
        state.git_scroll = ScrollState {
            offset: 0,
            total_lines: 20,
            visible_height: 10,
        };
        // term_height=50, bottom_panel=20 → bottom starts at row 30
        // mouse at exactly row 30 → in bottom panel
        state.handle_mouse_scroll(30, 50, 20, 3);
        assert_eq!(state.git_scroll.offset, 3);
        assert_eq!(state.agents_scroll.offset, 0);
    }

    #[test]
    fn mouse_scroll_just_above_boundary_goes_to_agents() {
        let mut state = AppState::new("%99".into());
        state.agents_scroll = ScrollState {
            offset: 0,
            total_lines: 40,
            visible_height: 20,
        };
        // row 29, just above bottom_start=30
        state.handle_mouse_scroll(29, 50, 20, 3);
        assert_eq!(state.agents_scroll.offset, 3);
        assert_eq!(state.activity_scroll.offset, 0);
    }

    // ─── move_agent_selection edge cases ─────────────────────────────

    #[test]
    fn move_agent_selection_returns_false_when_empty() {
        let mut state = AppState::new("%99".into());
        assert!(!state.move_agent_selection(1));
        assert!(!state.move_agent_selection(-1));
    }

    #[test]
    fn move_agent_selection_boundary_returns() {
        let mut state = AppState::new("%99".into());
        state.agent_row_targets = vec![
            RowTarget {
                pane_id: "%1".into(),
            },
            RowTarget {
                pane_id: "%2".into(),
            },
            RowTarget {
                pane_id: "%3".into(),
            },
        ];
        state.selected_agent_row = 0;

        assert!(!state.move_agent_selection(-1), "can't go below 0");
        assert!(state.move_agent_selection(1));
        assert!(state.move_agent_selection(1));
        assert_eq!(state.selected_agent_row, 2);
        assert!(!state.move_agent_selection(1), "can't go past end");
    }

    // ─── rebuild_row_targets clamp tests ────────────────────────────

    #[test]
    fn rebuild_row_targets_clamps_selection_when_shrinks() {
        let mut state = AppState::new("%99".into());
        state.repo_groups = vec![RepoGroup {
            name: "project".into(),
            has_focus: true,
            panes: vec![
                (test_pane("%1"), PaneGitInfo::default()),
                (test_pane("%2"), PaneGitInfo::default()),
                (test_pane("%3"), PaneGitInfo::default()),
            ],
        }];
        state.selected_agent_row = 2;
        state.rebuild_row_targets();
        assert_eq!(state.selected_agent_row, 2);

        // Shrink to 1 pane
        state.repo_groups[0].panes = vec![(test_pane("%1"), PaneGitInfo::default())];
        state.rebuild_row_targets();
        assert_eq!(
            state.selected_agent_row, 0,
            "should clamp to last valid index"
        );
    }

    #[test]
    fn rebuild_row_targets_empty_groups() {
        let mut state = AppState::new("%99".into());
        state.selected_agent_row = 5;
        state.repo_groups = vec![];
        state.rebuild_row_targets();
        assert!(state.agent_row_targets.is_empty());
        // selected_agent_row stays as-is when targets empty (no clamp needed)
        assert_eq!(state.selected_agent_row, 5);
    }
}
