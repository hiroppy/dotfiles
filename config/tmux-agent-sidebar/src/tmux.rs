use std::process::Command;

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
    pub permission_mode: PermissionMode,
    pub subagents: Vec<String>,
    pub pane_pid: Option<u32>,
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
pub enum PermissionMode {
    Default,
    Plan,
    AcceptEdits,
    Auto,
    BypassPermissions,
}

impl PermissionMode {
    pub fn from_str(s: &str) -> Self {
        match s {
            "plan" => Self::Plan,
            "acceptEdits" => Self::AcceptEdits,
            "auto" => Self::Auto,
            "bypassPermissions" => Self::BypassPermissions,
            _ => Self::Default,
        }
    }

    pub fn badge(&self) -> &str {
        match self {
            Self::Default => "",
            Self::Plan => "plan",
            Self::AcceptEdits => "edit",
            Self::Auto => "auto",
            Self::BypassPermissions => "!",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum AgentType {
    Claude,
    Codex,
    #[allow(dead_code)]
    Unknown,
}

#[derive(Debug, Clone)]
pub struct WindowInfo {
    pub window_id: String,
    #[allow(dead_code)]
    pub window_index: u32,
    pub window_name: String,
    pub window_active: bool,
    pub auto_rename: bool,
    pub panes: Vec<PaneInfo>,
}

#[derive(Debug, Clone)]
pub struct SessionInfo {
    pub session_name: String,
    #[allow(dead_code)]
    pub attached: bool,
    pub windows: Vec<WindowInfo>,
}

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
    let output = Command::new("tmux").args(args).output().ok()?;
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
        "#{pane_active}|#{@pane_status}|#{@pane_attention}|#{@pane_agent}|#{@pane_name}|#{pane_current_path}|#{pane_current_command}|#{@pane_role}|#{pane_id}|#{@pane_prompt}|#{@pane_started_at}|#{@pane_wait_reason}|#{pane_pid}|#{@pane_subagents}|#{@pane_cwd}|#{@pane_permission_mode}",
    ]) {
        Some(s) => s,
        None => return vec![],
    };

    let mut panes = Vec::new();
    let mut codex_pids: Vec<(usize, u32)> = Vec::new();

    for line in pane_output.lines() {
        if let Some(pane) = parse_pane_line(line) {
            let idx = panes.len();
            if pane.agent == AgentType::Codex {
                if let Some(pid) = pane.pane_pid {
                    codex_pids.push((idx, pid));
                }
            }
            panes.push(pane);
        }
    }

    // Detect Codex permission modes from process args
    if !codex_pids.is_empty() {
        if let Ok(output) = Command::new("ps").args(["-eo", "ppid,args"]).output() {
            if output.status.success() {
                let ps_out = String::from_utf8_lossy(&output.stdout);
                apply_codex_permission_modes(&mut panes, &codex_pids, &ps_out);
            }
        }
    }

    panes
}

/// Parse a single pane line from `tmux list-panes -F`.
/// Returns None if the line has fewer than 16 fields, is a sidebar, or has no agent.
pub(crate) fn parse_pane_line(line: &str) -> Option<PaneInfo> {
    let parts: Vec<&str> = line.splitn(16, '|').collect();
    if parts.len() < 16 {
        return None;
    }

    if parts[7] == "sidebar" {
        return None;
    }

    let agent = AgentType::from_str(parts[3])?;

    let pane_pid: Option<u32> = parts[12].parse().ok();

    // Prefer @pane_cwd (set by hook from agent's cwd) over pane_current_path
    let pane_cwd = parts[14];
    let path = if !pane_cwd.is_empty() {
        pane_cwd.to_string()
    } else {
        parts[5].to_string()
    };

    // Claude: read permission_mode from hook-set tmux variable
    // Codex: no permission_mode in hooks, detect from process args later
    let permission_mode = if agent == AgentType::Claude {
        PermissionMode::from_str(parts[15])
    } else {
        PermissionMode::Default
    };

    Some(PaneInfo {
        pane_active: parts[0] == "1",
        status: PaneStatus::from_str(parts[1]),
        attention: !parts[2].is_empty(),
        agent,
        pane_name: parts[4].to_string(),
        path,
        command: parts[6].to_string(),
        role: parts[7].to_string(),
        pane_id: parts[8].to_string(),
        prompt: parts[9].replace('|', " ").replace('\n', " "),
        started_at: parts[10].parse().ok(),
        wait_reason: parts[11].to_string(),
        permission_mode,
        subagents: parse_subagents(parts[13]),
        pane_pid,
    })
}

/// Detect Codex permission mode from process args (--full-auto, --yolo, etc.)
fn detect_codex_permission_mode(args: &str) -> PermissionMode {
    if args.contains("dangerously-bypass-approvals-and-sandbox") || args.contains("--yolo") {
        return PermissionMode::BypassPermissions;
    }
    if args.contains("--full-auto") {
        return PermissionMode::Auto;
    }
    PermissionMode::Default
}

fn apply_codex_permission_modes(
    panes: &mut [PaneInfo],
    pids_to_check: &[(usize, u32)],
    ps_out: &str,
) {
    for (idx, pid) in pids_to_check {
        let pid_str = pid.to_string();
        for line in ps_out.lines() {
            let trimmed = line.trim();
            if let Some((ppid_str, args)) = trimmed.split_once(char::is_whitespace) {
                if ppid_str.trim() != pid_str {
                    continue;
                }
                panes[*idx].permission_mode = detect_codex_permission_mode(args);
                if panes[*idx].permission_mode != PermissionMode::Default {
                    break;
                }
            }
        }
    }
}

/// Parse subagent list from tmux variable.
/// Format: comma-separated "type" entries, e.g. "Explore,Plan,Bash"
fn parse_subagents(raw: &str) -> Vec<String> {
    if raw.is_empty() {
        return vec![];
    }
    raw.split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
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

pub fn get_option(name: &str) -> Option<String> {
    run_tmux(&["show", "-gv", name])
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

pub fn get_pane_path(pane_id: &str) -> Option<String> {
    run_tmux(&[
        "display-message",
        "-t",
        pane_id,
        "-p",
        "#{pane_current_path}",
    ])
    .map(|s| s.trim().to_string())
    .filter(|s| !s.is_empty())
}

/// Query tmux for all panes in the active window, returning (pane_id, pane_active, path).
/// This queries tmux directly and is NOT filtered by agent type, so it includes
/// all panes (shell, editor, etc.) — not just agent panes.
pub fn query_active_window_panes() -> Vec<(String, bool, String)> {
    // List panes in the current (active) window across all sessions
    let output = match run_tmux(&[
        "list-panes",
        "-F",
        "#{pane_id}|#{pane_active}|#{pane_current_path}",
    ]) {
        Some(s) => s,
        None => return vec![],
    };
    output
        .lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.splitn(3, '|').collect();
            if parts.len() < 3 {
                return None;
            }
            Some((
                parts[0].to_string(),
                parts[1] == "1",
                parts[2].to_string(),
            ))
        })
        .collect()
}

/// Find the focused (non-sidebar) pane ID and path by querying tmux directly.
/// Returns all panes regardless of agent type, so activity/git info can be shown
/// even for non-agent panes.
pub fn find_active_pane(sidebar_pane: &str) -> Option<(String, String)> {
    pick_active_pane(sidebar_pane, &query_active_window_panes())
}

/// Pure logic: pick the active non-sidebar pane from a list.
/// Prefers pane_active=true with a non-empty path, then any non-sidebar
/// with a non-empty path. Returns None if only the sidebar exists or all
/// paths are empty.
pub(crate) fn pick_active_pane(
    sidebar_pane: &str,
    panes: &[(String, bool, String)],
) -> Option<(String, String)> {
    let valid = |p: &&(String, bool, String)| p.0 != sidebar_pane && !p.2.is_empty();
    let active = panes
        .iter()
        .find(|p| p.1 && valid(p))
        .or_else(|| panes.iter().find(valid));
    active.map(|p| (p.0.clone(), p.2.clone()))
}

/// Find the focused pane's working directory by querying tmux directly.
/// Used by the background git thread which doesn't have access to AppState.
/// Queries all panes (not just agent panes) so git info is available
/// even when the focused pane has no agent running.
pub fn focused_pane_path(sidebar_pane: &str) -> Option<String> {
    find_active_pane(sidebar_pane).map(|(_, path)| path)
}

pub fn select_pane(pane_id: &str) {
    // Find the window containing this pane and switch to it first
    if let Some(window_id) = run_tmux(&["display-message", "-t", pane_id, "-p", "#{window_id}"]) {
        let window_id = window_id.trim();
        if !window_id.is_empty() {
            let _ = run_tmux(&["select-window", "-t", window_id]);
        }
    }
    let _ = run_tmux(&["select-pane", "-t", pane_id]);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pane_status_from_str_all_variants() {
        assert_eq!(PaneStatus::from_str("running"), PaneStatus::Running);
        assert_eq!(PaneStatus::from_str("waiting"), PaneStatus::Waiting);
        assert_eq!(PaneStatus::from_str("notification"), PaneStatus::Waiting);
        assert_eq!(PaneStatus::from_str("idle"), PaneStatus::Idle);
        assert_eq!(PaneStatus::from_str("error"), PaneStatus::Error);
        assert_eq!(PaneStatus::from_str("anything"), PaneStatus::Unknown);
        assert_eq!(PaneStatus::from_str(""), PaneStatus::Unknown);
    }

    #[test]
    fn pane_status_icon_all_variants() {
        assert_eq!(PaneStatus::Running.icon(), "●");
        assert_eq!(PaneStatus::Waiting.icon(), "◐");
        assert_eq!(PaneStatus::Idle.icon(), "○");
        assert_eq!(PaneStatus::Error.icon(), "✕");
        assert_eq!(PaneStatus::Unknown.icon(), "·");
    }

    #[test]
    fn agent_type_from_str_all() {
        assert_eq!(AgentType::from_str("claude"), Some(AgentType::Claude));
        assert_eq!(AgentType::from_str("codex"), Some(AgentType::Codex));
        assert_eq!(AgentType::from_str("unknown"), None);
        assert_eq!(AgentType::from_str(""), None);
    }

    #[test]
    fn agent_type_label() {
        assert_eq!(AgentType::Claude.label(), "claude");
        assert_eq!(AgentType::Codex.label(), "codex");
        assert_eq!(AgentType::Unknown.label(), "unknown");
    }

    #[test]
    fn permission_mode_from_str_all() {
        assert_eq!(PermissionMode::from_str("default"), PermissionMode::Default);
        assert_eq!(PermissionMode::from_str("plan"), PermissionMode::Plan);
        assert_eq!(
            PermissionMode::from_str("acceptEdits"),
            PermissionMode::AcceptEdits
        );
        assert_eq!(PermissionMode::from_str("auto"), PermissionMode::Auto);
        assert_eq!(PermissionMode::from_str("dontAsk"), PermissionMode::Default);
        assert_eq!(
            PermissionMode::from_str("bypassPermissions"),
            PermissionMode::BypassPermissions
        );
        assert_eq!(PermissionMode::from_str(""), PermissionMode::Default);
        assert_eq!(PermissionMode::from_str("unknown"), PermissionMode::Default);
    }

    #[test]
    fn permission_mode_badge() {
        assert_eq!(PermissionMode::Default.badge(), "");
        assert_eq!(PermissionMode::Plan.badge(), "plan");
        assert_eq!(PermissionMode::AcceptEdits.badge(), "edit");
        assert_eq!(PermissionMode::Auto.badge(), "auto");
        assert_eq!(PermissionMode::BypassPermissions.badge(), "!");
        assert_eq!(PermissionMode::BypassPermissions.badge(), "!");
    }

    #[test]
    fn detect_codex_permission_mode_variants() {
        assert_eq!(
            detect_codex_permission_mode("codex"),
            PermissionMode::Default
        );
        assert_eq!(
            detect_codex_permission_mode("codex --full-auto"),
            PermissionMode::Auto
        );
        assert_eq!(
            detect_codex_permission_mode("codex --dangerously-bypass-approvals-and-sandbox"),
            PermissionMode::BypassPermissions
        );
        assert_eq!(
            detect_codex_permission_mode("codex --full-auto --yolo"),
            PermissionMode::BypassPermissions
        );
    }

    #[test]
    fn apply_codex_permission_modes_from_ps() {
        let mut panes = vec![PaneInfo {
            pane_id: "%1".into(),
            pane_active: false,
            status: PaneStatus::Idle,
            attention: false,
            agent: AgentType::Codex,
            pane_name: "one".into(),
            path: "/tmp".into(),
            command: "codex".into(),
            role: String::new(),
            prompt: String::new(),
            started_at: None,
            wait_reason: String::new(),
            permission_mode: PermissionMode::Default,
            subagents: vec![],
            pane_pid: None,
        }];
        let pids = vec![(0, 101)];
        let ps_out = " 101 /bin/codex --full-auto\n";

        apply_codex_permission_modes(&mut panes, &pids, ps_out);
        assert_eq!(panes[0].permission_mode, PermissionMode::Auto);
    }

    #[test]
    fn parse_subagents_empty() {
        assert_eq!(parse_subagents(""), Vec::<String>::new());
    }

    #[test]
    fn parse_subagents_single() {
        assert_eq!(parse_subagents("Explore"), vec!["Explore"]);
    }

    #[test]
    fn parse_subagents_multiple() {
        assert_eq!(
            parse_subagents("Explore,Plan,Bash"),
            vec!["Explore", "Plan", "Bash"]
        );
    }

    #[test]
    fn parse_subagents_numbered() {
        assert_eq!(
            parse_subagents("Explore #1,Explore #2,Plan"),
            vec!["Explore #1", "Explore #2", "Plan"]
        );
    }

    // ─── parse_pane_line tests ──────────────────────────────────────

    fn make_pane_line(fields: &[&str]) -> String {
        fields.join("|")
    }

    fn full_16_fields() -> Vec<&'static str> {
        vec![
            "1",                   // 0: pane_active
            "running",             // 1: @pane_status
            "",                    // 2: @pane_attention
            "claude",              // 3: @pane_agent
            "my-agent",            // 4: @pane_name
            "/home/user/project",  // 5: pane_current_path
            "fish",                // 6: pane_current_command
            "",                    // 7: @pane_role
            "%1",                  // 8: pane_id
            "fix the bug",         // 9: @pane_prompt
            "1700000000",          // 10: @pane_started_at
            "",                    // 11: @pane_wait_reason
            "12345",               // 12: pane_pid
            "Explore,Plan",        // 13: @pane_subagents
            "/custom/cwd",         // 14: @pane_cwd
            "auto",                // 15: @pane_permission_mode
        ]
    }

    #[test]
    fn parse_pane_line_full_16_fields() {
        let line = make_pane_line(&full_16_fields());
        let pane = parse_pane_line(&line).expect("should parse 16 fields");
        assert!(pane.pane_active);
        assert_eq!(pane.status, PaneStatus::Running);
        assert_eq!(pane.agent, AgentType::Claude);
        assert_eq!(pane.pane_name, "my-agent");
        assert_eq!(pane.path, "/custom/cwd"); // pane_cwd preferred
        assert_eq!(pane.pane_id, "%1");
        assert_eq!(pane.prompt, "fix the bug");
        assert_eq!(pane.started_at, Some(1700000000));
        assert_eq!(pane.pane_pid, Some(12345));
        assert_eq!(pane.subagents, vec!["Explore", "Plan"]);
        assert_eq!(pane.permission_mode, PermissionMode::Auto);
    }

    #[test]
    fn parse_pane_line_rejects_fewer_than_16_fields() {
        // Only 14 fields — should be rejected
        let fields_14 = "1|running||claude|name|/path|fish||%1|prompt|1700000000||12345|Explore";
        assert!(
            parse_pane_line(fields_14).is_none(),
            "14 fields should be rejected"
        );

        // 15 fields — still rejected
        let fields_15 =
            "1|running||claude|name|/path|fish||%1|prompt|1700000000||12345|Explore|/cwd";
        assert!(
            parse_pane_line(fields_15).is_none(),
            "15 fields should be rejected"
        );
    }

    #[test]
    fn parse_pane_line_rejects_sidebar_role() {
        let mut fields = full_16_fields();
        fields[7] = "sidebar";
        let line = make_pane_line(&fields);
        assert!(
            parse_pane_line(&line).is_none(),
            "sidebar role should be filtered out"
        );
    }

    #[test]
    fn parse_pane_line_rejects_unknown_agent() {
        let mut fields = full_16_fields();
        fields[3] = ""; // no agent type
        let line = make_pane_line(&fields);
        assert!(
            parse_pane_line(&line).is_none(),
            "empty agent should be rejected"
        );
    }

    #[test]
    fn parse_pane_line_falls_back_to_pane_current_path() {
        let mut fields = full_16_fields();
        fields[14] = ""; // empty pane_cwd
        let line = make_pane_line(&fields);
        let pane = parse_pane_line(&line).unwrap();
        assert_eq!(
            pane.path, "/home/user/project",
            "should fall back to pane_current_path when pane_cwd is empty"
        );
    }

    // ─── pick_active_pane tests ───────────────────────────────────

    fn pane_tuple(id: &str, active: bool, path: &str) -> (String, bool, String) {
        (id.to_string(), active, path.to_string())
    }

    #[test]
    fn pick_active_pane_selects_active_non_sidebar() {
        let panes = vec![
            pane_tuple("%1", false, "/home/user/a"),
            pane_tuple("%2", true, "/home/user/b"),
            pane_tuple("%99", false, "/home/user/sidebar"),
        ];
        let result = pick_active_pane("%99", &panes);
        assert_eq!(result, Some(("%2".into(), "/home/user/b".into())));
    }

    #[test]
    fn pick_active_pane_skips_sidebar_even_if_active() {
        let panes = vec![
            pane_tuple("%1", false, "/home/user/a"),
            pane_tuple("%99", true, "/home/user/sidebar"),
        ];
        let result = pick_active_pane("%99", &panes);
        assert_eq!(
            result,
            Some(("%1".into(), "/home/user/a".into())),
            "should fall back to non-sidebar pane"
        );
    }

    #[test]
    fn pick_active_pane_falls_back_to_first_non_sidebar() {
        let panes = vec![
            pane_tuple("%99", false, "/sidebar"),
            pane_tuple("%1", false, "/home/user/a"),
            pane_tuple("%2", false, "/home/user/b"),
        ];
        let result = pick_active_pane("%99", &panes);
        assert_eq!(
            result,
            Some(("%1".into(), "/home/user/a".into())),
            "should pick first non-sidebar when none is active"
        );
    }

    #[test]
    fn pick_active_pane_none_when_only_sidebar() {
        let panes = vec![pane_tuple("%99", true, "/sidebar")];
        let result = pick_active_pane("%99", &panes);
        assert_eq!(result, None);
    }

    #[test]
    fn pick_active_pane_none_when_empty() {
        let result = pick_active_pane("%99", &[]);
        assert_eq!(result, None);
    }

    #[test]
    fn pick_active_pane_skips_empty_path_falls_back() {
        let panes = vec![
            pane_tuple("%1", true, ""),
            pane_tuple("%2", false, "/home/user/b"),
        ];
        let result = pick_active_pane("%99", &panes);
        // %1 is active but has empty path → skip, fall back to %2
        assert_eq!(
            result,
            Some(("%2".into(), "/home/user/b".into())),
            "should skip empty-path pane and fall back"
        );
    }

    // ─── parse_pane_line tests ──────────────────────────────────────

    #[test]
    fn parse_pane_line_codex_ignores_permission_mode_field() {
        let mut fields = full_16_fields();
        fields[3] = "codex";
        fields[15] = "auto"; // should be ignored for codex
        let line = make_pane_line(&fields);
        let pane = parse_pane_line(&line).unwrap();
        assert_eq!(
            pane.permission_mode,
            PermissionMode::Default,
            "codex should not read permission_mode from tmux variable"
        );
    }
}
