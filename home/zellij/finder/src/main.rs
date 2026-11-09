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

#[derive(Default)]
struct Finder {
    scope: Scope,
    ready: bool,
    entries: Vec<Entry>,
    query: String,
    shown: Vec<(usize, Vec<usize>)>,
    selected: usize,
}
register_plugin!(Finder);

impl Finder {
    fn update_sessions(&mut self, sessions: &[SessionInfo]) {
        self.entries = entries(sessions, self.scope);
        self.refilter();
    }

    /// `SessionUpdate` alone can leave out other sessions, so ask directly,
    /// as the built-in session manager does: now and every second.
    fn poll_sessions(&mut self) {
        if let Ok(snapshot) = get_session_list() {
            self.update_sessions(&snapshot.live_sessions);
        }
        set_timeout(1.0);
    }

    fn refilter(&mut self) {
        self.shown = filter(&self.entries, &self.query);
        self.selected = self.selected.min(self.shown.len().saturating_sub(1));
    }

    fn activate(&self) {
        if let Some(entry) = self
            .shown
            .get(self.selected)
            .map(|(i, _)| &self.entries[*i])
        {
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
            BareKey::Esc => close_self(),
            BareKey::Char('c') if ctrl => close_self(),
            BareKey::Enter => self.activate(),
            BareKey::Up => self.selected = self.selected.saturating_sub(1),
            BareKey::Char('p' | 'k') if ctrl => self.selected = self.selected.saturating_sub(1),
            BareKey::Down => self.move_down(),
            BareKey::Char('n' | 'j') if ctrl => self.move_down(),
            BareKey::Char('u') if ctrl => {
                self.query.clear();
                self.selected = 0;
                self.refilter();
            }
            BareKey::Backspace => {
                self.query.pop();
                self.selected = 0;
                self.refilter();
            }
            BareKey::Char(c)
                if !key.has_modifiers(&[KeyModifier::Ctrl])
                    && !key.has_modifiers(&[KeyModifier::Alt]) =>
            {
                self.query.push(c);
                self.selected = 0;
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
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::PermissionRequestResult(PermissionStatus::Granted) => {
                self.ready = true;
                rename_plugin_pane(get_plugin_ids().plugin_id, self.scope.title());
                self.poll_sessions();
                true
            }
            Event::Timer(_) if self.ready => {
                self.poll_sessions();
                true
            }
            Event::SessionUpdate(sessions, _) => {
                self.update_sessions(&sessions);
                true
            }
            Event::Key(key) if self.ready => self.key(&key),
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        if !self.ready {
            return;
        }
        let width = Some(cols.saturating_sub(2));
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
    fn empty_query_keeps_the_order() {
        assert_eq!(found(Scope::Tabs, ""), ["edit", "shell"]);
    }
}
