use std::collections::HashSet;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::activity::{self, TaskProgress};
use crate::tmux::{self, SessionInfo};

use super::AppState;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum TaskProgressDecision {
    Clear,
    Show,
    Dismiss { total: usize },
    Skip,
}

pub(crate) fn classify_task_progress(
    progress: &TaskProgress,
    dismissed_total: Option<usize>,
) -> TaskProgressDecision {
    if progress.is_empty() {
        return TaskProgressDecision::Clear;
    }
    if progress.all_completed() {
        if dismissed_total == Some(progress.total()) {
            TaskProgressDecision::Skip
        } else {
            TaskProgressDecision::Dismiss {
                total: progress.total(),
            }
        }
    } else {
        TaskProgressDecision::Show
    }
}

impl AppState {
    pub(crate) fn refresh_now(&mut self) {
        self.now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
    }

    pub(crate) fn apply_session_snapshot(
        &mut self,
        sidebar_focused: bool,
        sessions: Vec<SessionInfo>,
    ) {
        self.sidebar_focused = sidebar_focused;
        self.sessions = sessions;
        self.repo_groups = crate::group::group_panes_by_repo(&self.sessions);
        self.rebuild_row_targets();
        self.find_focused_pane();
    }

    fn refresh_activity_data(&mut self) {
        self.refresh_activity_log();
        self.refresh_task_progress();
        self.auto_switch_tab();
    }

    /// Fast refresh: tmux state + activity log (called every 1s)
    pub fn refresh(&mut self) {
        self.refresh_now();
        let (focused, _, _) = tmux::get_sidebar_pane_info(&self.tmux_pane);
        self.apply_session_snapshot(focused, tmux::query_sessions());
        self.refresh_activity_data();
    }

    pub(crate) fn refresh_task_progress(&mut self) {
        self.pane_task_progress.clear();
        let mut active_pane_ids: HashSet<&str> = HashSet::new();
        for group in &self.repo_groups {
            for (pane, _) in &group.panes {
                active_pane_ids.insert(&pane.pane_id);
                let entries = activity::read_activity_log(&pane.pane_id, self.activity_max_entries);
                let progress = activity::parse_task_progress(&entries);
                match classify_task_progress(
                    &progress,
                    self.pane_task_dismissed.get(&pane.pane_id).copied(),
                ) {
                    TaskProgressDecision::Clear => {
                        self.pane_task_dismissed.remove(&pane.pane_id);
                    }
                    TaskProgressDecision::Show => {
                        self.pane_task_dismissed.remove(&pane.pane_id);
                        self.pane_task_progress
                            .insert(pane.pane_id.clone(), progress);
                    }
                    TaskProgressDecision::Dismiss { total } => {
                        self.pane_task_dismissed.insert(pane.pane_id.clone(), total);
                    }
                    TaskProgressDecision::Skip => {}
                }
            }
        }
        self.pane_task_dismissed
            .retain(|id, _| active_pane_ids.contains(id.as_str()));
    }

    pub(crate) fn refresh_activity_log(&mut self) {
        if let Some(ref pane_id) = self.focused_pane_id {
            self.activity_entries = activity::read_activity_log(pane_id, self.activity_max_entries);
        } else {
            self.activity_entries.clear();
        }
    }
}
