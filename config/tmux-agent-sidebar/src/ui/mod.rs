pub mod agents;
pub mod bottom;
pub mod colors;
pub mod text;

use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout},
    widgets::Paragraph,
};

use crate::state::AppState;

pub const BOTTOM_PANEL_HEIGHT: u16 = 20;

// ── public entry point ──────────────────────────────────────────────

pub fn draw(frame: &mut Frame, state: &mut AppState) {
    let area = frame.area();

    if state.sessions.is_empty() {
        let msg = Paragraph::new("No agent panes found");
        frame.render_widget(msg, area);
        return;
    }

    let bot_h = BOTTOM_PANEL_HEIGHT;

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(if bot_h > 0 {
            vec![
                Constraint::Min(1),
                Constraint::Length(1),
                Constraint::Length(bot_h),
            ]
        } else {
            vec![Constraint::Min(1)]
        })
        .split(area);

    agents::draw_agents(frame, state, chunks[0]);

    if bot_h > 0 && chunks.len() > 2 {
        bottom::draw_bottom(frame, state, chunks[2]);
    }
}
