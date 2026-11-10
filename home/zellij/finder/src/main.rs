//! A fuzzy finder for sessions, the current session's tabs, or every
//! session's tabs (`scope` = `sessions`, `tabs` or `all`). Each word of the
//! query must match, in any order, so `nix edit` finds the tab `edit` in the
//! session `nix`.

use fuzzy_matcher::FuzzyMatcher;
use fuzzy_matcher::skim::SkimMatcherV2;
use std::collections::BTreeMap;
use zellij_tile::prelude::*;

#[derive(Clone, Copy, Default, PartialEq, Debug)]
enum Scope {
    Sessions,
    Tabs,
    #[default]
    All,
}

impl Scope {
    fn parse(value: Option<&String>) -> Self {
        match value.map(String::as_str) {
            Some("sessions") => Self::Sessions,
            Some("tabs") => Self::Tabs,
            _ => Self::All,
        }
    }

    fn title(self) -> &'static str {
        match self {
            Self::Sessions => "Sessions",
            Self::Tabs => "Tabs",
            Self::All => "Sessions and tabs",
        }
    }
}

/// Something to switch to: a session, or a tab (position, name) in one.
#[derive(Clone, PartialEq, Debug)]
struct Entry {
    session: String,
    tab: Option<usize>,
    in_current_session: bool,
    /// Where you are now: the current session, or its active tab.
    here: bool,
    label: String,
}

/// The entries for a scope: the current session's first, then the others
/// by name; tabs in tab bar order.
fn entries(sessions: &[SessionInfo], scope: Scope) -> Vec<Entry> {
    let mut sessions: Vec<&SessionInfo> = sessions.iter().collect();
    sessions.sort_by_key(|s| (!s.is_current_session, s.name.clone()));
    let mut entries = vec![];
    for session in sessions {
        let current = session.is_current_session;
        if scope == Scope::Sessions {
            entries.push(Entry {
                session: session.name.clone(),
                tab: None,
                in_current_session: current,
                here: current,
                label: session.name.clone(),
            });
            continue;
        }
        if scope == Scope::Tabs && !current {
            continue;
        }
        let mut tabs: Vec<&TabInfo> = session.tabs.iter().collect();
        tabs.sort_by_key(|t| t.position);
        for tab in tabs {
            let label = match scope {
                Scope::All => format!("{} › {}", session.name, tab.name),
                _ => tab.name.clone(),
            };
            entries.push(Entry {
                session: session.name.clone(),
                tab: Some(tab.position),
                in_current_session: current,
                here: current && tab.active,
                label,
            });
        }
    }
    entries
}

/// Each word of the query fuzzy-matched against the label: the total score
/// and the matched character positions, or None if any word doesn't match.
fn score(matcher: &SkimMatcherV2, label: &str, query: &str) -> Option<(i64, Vec<usize>)> {
    let mut total = 0;
    let mut indices = vec![];
    for word in query.split_whitespace() {
        let (score, mut found) = matcher.fuzzy_indices(label, word)?;
        total += score;
        indices.append(&mut found);
    }
    indices.sort_unstable();
    indices.dedup();
    Some((total, indices))
}

/// The entries matching the query, best first (ties keep list order): each
/// entry's index and its matched character positions.
fn filter(entries: &[Entry], query: &str) -> Vec<(usize, Vec<usize>)> {
    let matcher = SkimMatcherV2::default(); // smart case
    let mut found: Vec<(i64, usize, Vec<usize>)> = entries
        .iter()
        .enumerate()
        .filter_map(|(i, e)| score(&matcher, &e.label, query).map(|(s, idx)| (s, i, idx)))
        .collect();
    found.sort_by_key(|(s, i, _)| (-s, *i));
    found.into_iter().map(|(_, i, idx)| (i, idx)).collect()
}

/// Esc or Ctrl c: close the finder.
fn closes(key: &KeyWithModifier) -> bool {
    match key.bare_key {
        BareKey::Esc => true,
        BareKey::Char('c') => key.has_modifiers(&[KeyModifier::Ctrl]),
        _ => false,
    }
}

#[derive(Default)]
struct Finder {
    scope: Scope,
    ready: bool,
    denied: bool,
    /// A `SessionUpdate` arrived, so reading Zellij's state is really
    /// allowed: until then `get_session_list` could panic (if zellij reports
    /// a grant it didn't apply, as for a pane restored with a session).
    readable: bool,
    /// The last session list, and this session's tabs as of the last
    /// `TabUpdate`: fresher than the list's, which Zellij updates on disk
    /// once a second.
    sessions: Vec<SessionInfo>,
    tabs: Option<Vec<TabInfo>>,
    entries: Vec<Entry>,
    query: String,
    shown: Vec<(usize, Vec<usize>)>,
    selected: usize,
}
register_plugin!(Finder);

impl Finder {
    fn selected_entry(&self) -> Option<&Entry> {
        self.shown
            .get(self.selected)
            .map(|(i, _)| &self.entries[*i])
    }

    /// New entries, keeping the same session or tab selected while it's
    /// still shown, so Enter doesn't land on whatever moved under the cursor.
    /// Whether they changed (else there's nothing to redraw).
    fn update_sessions(&mut self, sessions: &[SessionInfo]) -> bool {
        let entries = entries(sessions, self.scope);
        if entries == self.entries {
            return false;
        }
        let kept = self.selected_entry().map(|e| (e.session.clone(), e.tab));
        let first = kept.is_none() && self.query.is_empty();
        self.entries = entries;
        self.shown = filter(&self.entries, &self.query);
        if let Some(position) = kept.and_then(|(session, tab)| {
            self.shown.iter().position(|(i, _)| {
                let e = &self.entries[*i];
                e.session == session && e.tab == tab
            })
        }) {
            self.selected = position;
        } else if first {
            // Start somewhere other than where you are.
            self.selected = self
                .shown
                .iter()
                .position(|(i, _)| !self.entries[*i].here)
                .unwrap_or(0);
        }
        self.selected = self.selected.min(self.shown.len().saturating_sub(1));
        true
    }

    /// `SessionUpdate` alone can leave out other sessions, so its list is
    /// never used: ask directly instead (as the built-in session manager
    /// also does, on a timer).
    fn refresh_sessions(&mut self) -> bool {
        if !self.readable {
            return false;
        }
        match get_session_list() {
            Ok(snapshot) => {
                self.sessions = snapshot.live_sessions;
                self.rebuild()
            }
            Err(_) => false,
        }
    }

    /// Entries from the last session list, with this session's latest tabs.
    fn rebuild(&mut self) -> bool {
        let mut sessions = self.sessions.clone();
        if let Some(tabs) = &self.tabs {
            for session in sessions.iter_mut().filter(|s| s.is_current_session) {
                session.tabs.clone_from(tabs);
            }
        }
        self.update_sessions(&sessions)
    }

    /// Refresh now and every second.
    fn poll_sessions(&mut self) -> bool {
        set_timeout(1.0);
        self.refresh_sessions()
    }

    /// The query changed: the best match is selected.
    fn refilter(&mut self) {
        self.shown = filter(&self.entries, &self.query);
        self.selected = 0;
    }

    fn activate(&self) {
        if let Some(entry) = self.selected_entry() {
            match (entry.in_current_session, entry.tab) {
                (true, Some(position)) => go_to_tab(u32::try_from(position).unwrap_or(0)),
                (true, None) => {}
                (false, tab) => switch_session_with_focus(&entry.session, tab, None),
            }
        }
        close_self();
    }

    fn key(&mut self, key: &KeyWithModifier) -> bool {
        let ctrl = key.has_modifiers(&[KeyModifier::Ctrl]);
        match key.bare_key {
            _ if closes(key) => close_self(),
            BareKey::Enter => self.activate(),
            BareKey::Up => self.selected = self.selected.saturating_sub(1),
            BareKey::Char('p' | 'k') if ctrl => self.selected = self.selected.saturating_sub(1),
            BareKey::Down => self.move_down(),
            BareKey::Char('n' | 'j') if ctrl => self.move_down(),
            BareKey::Char('u') if ctrl => {
                self.query.clear();
                self.refilter();
            }
            BareKey::Backspace => {
                self.query.pop();
                self.refilter();
            }
            BareKey::Char(c) if !ctrl && !key.has_modifiers(&[KeyModifier::Alt]) => {
                self.query.push(c);
                self.refilter();
            }
            _ => return false,
        }
        true
    }

    fn move_down(&mut self) {
        if self.selected + 1 < self.shown.len() {
            self.selected += 1;
        }
    }
}

impl ZellijPlugin for Finder {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        self.scope = Scope::parse(configuration.get("scope"));
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
        subscribe(&[
            EventType::PermissionRequestResult,
            EventType::SessionUpdate,
            EventType::Key,
            EventType::Timer,
            EventType::Visible,
            EventType::TabUpdate,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::PermissionRequestResult(PermissionStatus::Granted) => {
                self.ready = true;
                // (which also brings the first SessionUpdate)
                rename_plugin_pane(get_plugin_ids().plugin_id, self.scope.title());
                self.poll_sessions();
                true
            }
            Event::Timer(_) if self.ready => self.poll_sessions(),
            Event::PermissionRequestResult(PermissionStatus::Denied) => {
                self.denied = true;
                true
            }
            Event::TabUpdate(tabs) => {
                self.tabs = Some(tabs);
                self.rebuild() && self.ready
            }
            // The first one shows reading is allowed (see `readable`). Then
            // stop listening: get_session_list sends a SessionUpdate itself,
            // so refreshing on each would loop. The timer refreshes the list.
            Event::SessionUpdate(..) => {
                self.readable = true;
                unsubscribe(&[EventType::SessionUpdate]);
                self.refresh_sessions() && self.ready
            }
            // A picker off screen (another tab or session, or brought back
            // with a resurrected session) has no reason to stay open.
            Event::Visible(false) => {
                close_self();
                false
            }
            Event::Key(key) if self.ready => self.key(&key),
            // Not ready: the pane can still be closed.
            Event::Key(key) if closes(&key) => {
                close_self();
                false
            }
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        let width = Some(cols.saturating_sub(2));
        if !self.ready {
            let message = if self.denied {
                "Permission denied. Esc to close."
            } else {
                "Waiting for permission. Esc to close."
            };
            print_text_with_coordinates(Text::new(message), 1, 0, width, None);
            return;
        }
        let count = format!("{}/{}", self.shown.len(), self.entries.len());
        let prompt = format!("> {}", self.query);
        let gap = cols.saturating_sub(prompt.chars().count() + count.chars().count() + 3);
        let line = format!("{prompt}{}{count}", " ".repeat(gap.max(1)));
        let count_start = line.chars().count() - count.chars().count();
        print_text_with_coordinates(
            Text::new(line)
                .color_range(2, 0..1)
                .color_range(1, count_start..),
            1,
            0,
            width,
            None,
        );

        // Scrolled so the selection stays in view.
        let list_rows = rows.saturating_sub(2);
        let offset = (self.selected + 1).saturating_sub(list_rows);
        for (y, (row, (i, indices))) in self
            .shown
            .iter()
            .enumerate()
            .skip(offset)
            .take(list_rows)
            .enumerate()
        {
            let entry = &self.entries[*i];
            let mut label = entry.label.clone();
            if entry.here {
                label.push_str("  (current)");
            }
            let mut text = Text::new(label).color_indices(3, indices.clone());
            if entry.here {
                text = text.color_range(1, entry.label.chars().count()..);
            }
            if row == self.selected {
                text = text.selected();
            }
            print_text_with_coordinates(text, 1, y + 2, width, None);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session(name: &str, current: bool, tabs: &[(&str, bool)]) -> SessionInfo {
        SessionInfo {
            name: name.into(),
            is_current_session: current,
            tabs: tabs
                .iter()
                .enumerate()
                .map(|(position, (name, active))| TabInfo {
                    position,
                    name: (*name).into(),
                    active: *active,
                    ..TabInfo::default()
                })
                .collect(),
            ..SessionInfo::default()
        }
    }

    fn sessions() -> Vec<SessionInfo> {
        vec![
            session("work", false, &[("build", true), ("logs", false)]),
            session("nix", true, &[("edit", false), ("shell", true)]),
            session("caiman", false, &[("train", true)]),
        ]
    }

    fn labels(entries: &[Entry]) -> Vec<&str> {
        entries.iter().map(|e| e.label.as_str()).collect()
    }

    fn found(scope: Scope, query: &str) -> Vec<String> {
        let entries = entries(&sessions(), scope);
        filter(&entries, query)
            .iter()
            .map(|(i, _)| entries[*i].label.clone())
            .collect()
    }

    #[test]
    fn current_session_first_then_by_name() {
        assert_eq!(
            labels(&entries(&sessions(), Scope::Sessions)),
            ["nix", "caiman", "work"]
        );
    }

    #[test]
    fn tabs_are_the_current_sessions() {
        let tabs = entries(&sessions(), Scope::Tabs);
        assert_eq!(labels(&tabs), ["edit", "shell"]);
        assert!(tabs[1].here && !tabs[0].here);
    }

    #[test]
    fn all_is_session_and_tab() {
        let all = entries(&sessions(), Scope::All);
        assert_eq!(all[0].label, "nix › edit");
        assert_eq!(all.len(), 5);
        // Another session's active tab is not where you are.
        assert!(!all.iter().any(|e| e.session == "work" && e.here));
    }

    #[test]
    fn words_match_in_any_order() {
        assert_eq!(found(Scope::All, "nix edit"), ["nix › edit"]);
        assert_eq!(found(Scope::All, "edit nix"), ["nix › edit"]);
        assert_eq!(found(Scope::All, "wrk lgs"), ["work › logs"]);
        assert_eq!(found(Scope::All, "nix train"), Vec::<String>::new());
    }

    #[test]
    fn sessions_scope_ignores_tab_names() {
        assert_eq!(found(Scope::Sessions, "edit"), Vec::<String>::new());
    }

    #[test]
    fn updates_keep_the_selected_entry() {
        let mut finder = Finder::default();
        finder.update_sessions(&sessions());
        finder.selected = 2; // caiman › train
        let mut more = sessions();
        more.push(session("api", false, &[("serve", true)]));
        finder.update_sessions(&more);
        assert_eq!(finder.selected_entry().unwrap().label, "caiman › train");
        // Gone: the same row, within the shorter list.
        finder.selected = 5; // work › logs
        finder.update_sessions(&sessions()[1..2]);
        assert_eq!(finder.selected, 1);
    }

    #[test]
    fn starts_away_from_where_you_are() {
        let mut finder = Finder {
            scope: Scope::Tabs,
            ..Finder::default()
        };
        finder.update_sessions(&sessions()); // tabs edit, shell (current)
        assert_eq!(finder.selected_entry().unwrap().label, "edit");
        let mut finder = Finder {
            scope: Scope::Sessions,
            ..Finder::default()
        };
        finder.update_sessions(&sessions()); // nix (current), caiman, work
        assert_eq!(finder.selected_entry().unwrap().label, "caiman");
    }

    #[test]
    fn empty_query_keeps_the_order() {
        assert_eq!(found(Scope::Tabs, ""), ["edit", "shell"]);
    }
}
