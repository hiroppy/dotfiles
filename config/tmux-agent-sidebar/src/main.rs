use std::io;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::time::Duration;

use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{Terminal, backend::CrosstermBackend};
use tmux_agent_sidebar::SPINNER_PULSE;
use tmux_agent_sidebar::git::{self, GitData};
use tmux_agent_sidebar::state::{AppState, Focus};
use tmux_agent_sidebar::tmux;
use tmux_agent_sidebar::ui;

static NEEDS_REFRESH: AtomicBool = AtomicBool::new(false);

fn main() -> io::Result<()> {
    let tmux_pane = std::env::var("TMUX_PANE").unwrap_or_default();
    if tmux_pane.is_empty() {
        eprintln!("TMUX_PANE not set");
        std::process::exit(1);
    }

    unsafe {
        let mut sa: libc::sigaction = std::mem::zeroed();
        sa.sa_sigaction = sigusr1_handler as *const () as libc::sighandler_t;
        sa.sa_flags = libc::SA_RESTART;
        libc::sigaction(libc::SIGUSR1, &sa, std::ptr::null_mut());
    }

    let pid = std::process::id();
    let _ = std::process::Command::new("tmux")
        .args([
            "set",
            "-t",
            &tmux_pane,
            "-p",
            "@sidebar_pid",
            &pid.to_string(),
        ])
        .output();

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = run_app(&mut terminal, tmux_pane);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;

    result
}

fn run_app(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    tmux_pane: String,
) -> io::Result<()> {
    let mut state = AppState::new(tmux_pane);
    state.theme = tmux_agent_sidebar::ui::colors::ColorTheme::from_tmux();
    state.refresh();

    if let Some(ref pane_id) = state.focused_pane_id {
        if let Some(path) = tmux::get_pane_path(pane_id) {
            state.apply_git_data(git::fetch_git_data(&path));
        }
    }

    let (git_tx, git_rx) = mpsc::channel::<GitData>();
    let tmux_pane_clone = state.tmux_pane.clone();
    std::thread::spawn(move || {
        loop {
            std::thread::sleep(Duration::from_secs(5));
            let path = tmux::focused_pane_path(&tmux_pane_clone);
            if let Some(path) = path {
                let data = git::fetch_git_data(&path);
                if git_tx.send(data).is_err() {
                    break;
                }
            }
        }
    });

    let mut last_refresh = std::time::Instant::now();
    let mut last_spinner = std::time::Instant::now();
    let refresh_interval = Duration::from_secs(1);
    let spinner_interval = Duration::from_millis(200);

    loop {
        terminal.draw(|frame| ui::draw(frame, &mut state))?;

        let refresh_timeout = refresh_interval.saturating_sub(last_refresh.elapsed());
        let spinner_timeout = spinner_interval.saturating_sub(last_spinner.elapsed());
        let timeout = refresh_timeout.min(spinner_timeout);
        if event::poll(timeout)? {
            // Drain all pending events to avoid lag
            loop {
                let ev = event::read()?;
                match ev {
                    Event::Key(key) => match key.code {
                        KeyCode::Esc => {
                            if state.focus == Focus::ActivityLog {
                                state.focus = Focus::Agents;
                            }
                        }
                        KeyCode::Char('j') | KeyCode::Down => match state.focus {
                            Focus::Agents => {
                                if !state.move_agent_selection(1) {
                                    // At bottom of agents list -> move to bottom panel
                                    state.focus = Focus::ActivityLog;
                                }
                            }
                            Focus::ActivityLog => state.scroll_bottom(1),
                        },
                        KeyCode::Char('k') | KeyCode::Up => match state.focus {
                            Focus::Agents => {
                                state.move_agent_selection(-1);
                            }
                            Focus::ActivityLog => {
                                // At top of scroll -> move back to agents
                                let at_top = match state.bottom_tab {
                                    tmux_agent_sidebar::state::BottomTab::Activity => {
                                        state.activity_scroll.offset == 0
                                    }
                                    tmux_agent_sidebar::state::BottomTab::GitStatus => {
                                        state.git_scroll.offset == 0
                                    }
                                };
                                if at_top {
                                    state.focus = Focus::Agents;
                                } else {
                                    state.scroll_bottom(-1);
                                }
                            }
                        },
                        KeyCode::Char('l') | KeyCode::Enter => {
                            if state.focus == Focus::Agents {
                                state.activate_selection();
                            }
                        }
                        KeyCode::Tab => {
                            state.next_bottom_tab();
                        }
                        _ => {}
                    },
                    _ => {}
                }
                // Check if more events are queued (non-blocking)
                if !event::poll(Duration::ZERO)? {
                    break;
                }
            }
        }

        if last_spinner.elapsed() >= spinner_interval {
            state.spinner_frame = (state.spinner_frame + 1) % SPINNER_PULSE.len();
            last_spinner = std::time::Instant::now();
        }

        if NEEDS_REFRESH.swap(false, Ordering::Relaxed) {
            state.refresh();
            last_refresh = std::time::Instant::now();
        }

        if last_refresh.elapsed() >= refresh_interval {
            state.refresh();
            last_refresh = std::time::Instant::now();
        }

        if let Ok(data) = git_rx.try_recv() {
            state.apply_git_data(data);
        }
    }
}

extern "C" fn sigusr1_handler(_: libc::c_int) {
    NEEDS_REFRESH.store(true, Ordering::Relaxed);
}
