//! A menu of the current mode's keys, in a corner while a menu mode is on.
//!
//! One instance runs in the background (`controller true`), which is the
//! only kind that hears every mode change; on entering a menu mode it
//! opens another, with no configuration, as a popup. The popup follows the
//! mode itself, and closes when the menu is left. Zellij keeps a popup
//! unfocused, within the screen, and with its client across tabs.

use std::collections::BTreeMap;
use std::fmt::Write as _;
use zellij_tile::prelude::{actions::Action, *};

/// The popup's alias in Zellij's config (`plugins`, in zellij.nix).
const POPUP: &str = "hints";

#[derive(Default)]
struct Hints {
    controller: bool,
    /// Controller: a menu is on, so its popup is open.
    menu: bool,
    /// Popup: what it shows.
    mode: InputMode,
    rows: Vec<(String, String)>,
}
register_plugin!(Hints);

impl ZellijPlugin for Hints {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        self.controller = configuration.get("controller").is_some_and(|v| v == "true");
        // (ModeUpdate only comes once reading is allowed, so nothing here
        // runs before the permissions are granted.)
        subscribe(&[EventType::ModeUpdate]);
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        let Event::ModeUpdate(info) = event else {
            return false;
        };
        let rows = bindings(&info);
        let menu = is_menu(info.mode) && !rows.is_empty();
        if self.controller {
            if menu && !self.menu {
                let (width, height) = size(info.mode, &rows);
                open_plugin_popup_with_options(
                    POPUP,
                    BTreeMap::new(),
                    0,
                    0,
                    width,
                    height,
                    PopupOptions::default()
                        .focused(false)
                        .corner(PopupCorner::BottomRight),
                );
            }
            self.menu = menu;
            return false;
        }
        // Also what ends a hints pane from a session saved before the
        // popups: it closes at the first mode it hears of.
        if !menu {
            close_self();
            return false;
        }
        if (self.mode, &self.rows) == (info.mode, &rows) {
            return false;
        }
        let (width, height) = size(info.mode, &rows);
        set_popup_size(width, height);
        self.mode = info.mode;
        self.rows = rows;
        true
    }

    fn render(&mut self, rows: usize, cols: usize) {
        if self.rows.is_empty() || rows < 2 || cols < 2 {
            return;
        }
        // A popup has no frame of its own.
        let inner = cols - 2;
        let title: String = title(self.mode).chars().take(inner).collect();
        let fill = "─".repeat(inner - title.chars().count());
        print_text_with_coordinates(
            Text::from(format!("╭{title}{fill}╮")).color_range(0, 1..=title.chars().count()),
            0,
            0,
            Some(cols),
            None,
        );
        let key_width = key_width(&self.rows);
        for y in 1..rows - 1 {
            let line = self
                .rows
                .get(y - 1)
                .map_or(String::new(), |(key, description)| {
                    format!(" {key:<key_width$}  {description}")
                });
            let line: String = line.chars().take(inner).collect();
            let keys = self
                .rows
                .get(y - 1)
                .map_or(0, |(key, _)| key.chars().count());
            print_text_with_coordinates(
                Text::from(format!("│{line:<inner$}│")).color_range(3, 2..2 + keys),
                0,
                y,
                Some(cols),
                None,
            );
        }
        print_text_with_coordinates(
            Text::from(format!("╰{}╯", "─".repeat(inner))),
            0,
            rows - 1,
            Some(cols),
            None,
        );
    }
}

/// The modes with a menu: the ones reached through `Alt g`.
fn is_menu(mode: InputMode) -> bool {
    matches!(
        mode,
        InputMode::Normal
            | InputMode::Pane
            | InputMode::Tab
            | InputMode::Session
            | InputMode::Resize
            | InputMode::Prompt
    )
}

fn title(mode: InputMode) -> String {
    format!(" {mode:?} ")
}

fn key_width(rows: &[(String, String)]) -> usize {
    rows.iter()
        .map(|(k, _)| k.chars().count())
        .max()
        .unwrap_or(0)
}

/// The popup's (width, height) for these rows: a frame, around each row as
/// ` key  description `.
fn size(mode: InputMode, rows: &[(String, String)]) -> (usize, usize) {
    let descriptions = rows
        .iter()
        .map(|(_, d)| d.chars().count())
        .max()
        .unwrap_or(0);
    let width = (key_width(rows) + descriptions + 4).max(title(mode).chars().count());
    (width + 2, rows.len() + 2)
}

fn bindings(info: &ModeInfo) -> Vec<(String, String)> {
    let mut groups: Vec<(String, String)> = Vec::new();
    // The keymap comes unordered; sort so the menu is stable: plain keys
    // first, then modified ones, alphabetically.
    let mut keybinds = info.get_keybinds_for_mode(info.mode);
    keybinds.sort_by_cached_key(|(key, _)| (!key.key_modifiers.is_empty(), key.to_string()));
    for (key, actions) in keybinds {
        // Plugin message details are stripped from ModeInfo, so match the keys.
        if key.has_modifiers(&[KeyModifier::Ctrl])
            && matches!(
                key.bare_key,
                BareKey::Left | BareKey::Right | BareKey::Up | BareKey::Down
            )
        {
            continue;
        }
        let Some(action) = actions.first() else {
            continue;
        };
        // Keep shared navigation and mode-exit shortcuts out of the menu.
        if matches!(
            action,
            Action::SwitchToMode {
                input_mode: InputMode::Locked,
            }
        ) {
            continue;
        }
        let description = describe(action);
        if let Some((keys, _)) = groups.iter_mut().find(|(_, label)| *label == description) {
            let _ = write!(keys, " / {key}"); // (a String write never fails)
        } else {
            groups.push((key.to_string(), description));
        }
    }
    groups
}

fn describe(action: &Action) -> String {
    match action {
        Action::SwitchToMode { input_mode } => match input_mode {
            InputMode::Tab => "Tabs".into(),
            InputMode::Pane => "Panes".into(),
            InputMode::Session => "Sessions".into(),
            InputMode::Prompt => "Quit session...".into(),
            InputMode::RenameSession => "Rename session".into(),
            mode => format!("{mode:?}"),
        },
        Action::NewPane {
            direction: Some(Direction::Down),
            ..
        } => "Split vertically (-)".into(),
        Action::NewPane {
            direction: Some(Direction::Right),
            ..
        } => "Split horizontally (|)".into(),
        Action::NewTab { .. } => "New tab".into(),
        Action::TabNameInput { .. } => "Rename tab".into(),
        Action::CloseTab => "Close tab".into(),
        Action::CloseFocus => "Close pane".into(),
        Action::FocusGuestSession => "Control nested session".into(),
        Action::FocusHostSession => "Control parent session".into(),
        Action::ToggleHostFullscreen => "Maximize / restore nested session".into(),
        Action::Detach => "Detach session".into(),
        // (the only message bound in a menu; ModeInfo has no more of it)
        Action::KeybindPipe { .. } => "Quit session, for every client".into(),
        Action::EditScrollback { .. } => "Open scrollback in editor".into(),
        action if action.launches_plugin("sessions") => "Manage sessions".into(),
        // New actions still appear without adding another menu entry here.
        action => format!("{action:?}")
            .split(['{', '('])
            .next()
            .unwrap_or("Action")
            .trim()
            .to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sized_to_the_longest_row_and_the_title() {
        let rows = vec![
            ("s".into(), "Sessions".into()),
            ("Alt x".into(), "Go".into()),
        ];
        // │ Alt x  Sessions │: the widest key and the widest description.
        assert_eq!(size(InputMode::Normal, &rows), (19, 4));
        let rows = vec![("y".into(), "Go".into())];
        assert_eq!(size(InputMode::Session, &rows), (" Session ".len() + 2, 3));
    }

    #[test]
    fn menus_are_the_modes_behind_alt_g() {
        assert!(is_menu(InputMode::Session));
        assert!(is_menu(InputMode::Prompt));
        assert!(!is_menu(InputMode::Locked));
        assert!(!is_menu(InputMode::RenameTab));
        assert!(!is_menu(InputMode::RenameSession));
    }
}
