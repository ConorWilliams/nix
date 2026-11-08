use std::collections::{BTreeMap, BTreeSet};
use zellij_tile::prelude::{actions::Action, *};

#[derive(Default)]
struct Hints {
    id: u32,
    ready: bool,
    visible: bool,
    mode: InputMode,
    rows: Vec<(String, String)>,
    size: (usize, usize),
    controller: bool,
    views: BTreeSet<u32>,
}
register_plugin!(Hints);

impl ZellijPlugin for Hints {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        self.id = get_plugin_ids().plugin_id;
        self.controller = configuration.get("controller").is_some_and(|v| v == "true");
        self.size = (24, 80);
        // Full ModeUpdate events supply the live keymap; no config parser or cache.
        subscribe(&[
            EventType::ModeUpdate,
            EventType::TabUpdate,
            EventType::PaneUpdate,
            EventType::PermissionRequestResult,
        ]);
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
            PermissionType::MessageAndLaunchOtherPlugins,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::PermissionRequestResult(PermissionStatus::Granted) => {
                self.ready = true;
                set_selectable(false);
                hide_self();
                self.refresh();
            }
            // Views get the mode piped from the controller, which also covers new views.
            Event::ModeUpdate(info) if self.controller => {
                let rows = bindings(&info);
                if self.mode != info.mode || self.rows != rows {
                    self.mode = info.mode;
                    self.rows = rows;
                    self.refresh();
                }
            }
            Event::TabUpdate(tabs) => {
                if let Some(tab) = tabs.iter().find(|t| t.active) {
                    let size = (tab.display_area_rows, tab.display_area_columns);
                    let changed = self.size != size;
                    self.size = size;
                    if self.ready && self.visible && changed {
                        self.refresh();
                    }
                }
            }
            Event::PaneUpdate(manifest) if self.controller && self.ready => {
                let mut views = BTreeSet::new();
                for panes in manifest.panes.values() {
                    let mut hints = panes
                        .iter()
                        .filter(|p| p.is_plugin && p.plugin_url.as_deref() == Some("hints"));
                    if let Some(pane) = hints.next() {
                        views.insert(pane.id);
                    }
                    // Closing a tab transfers suppressed panes to another tab.
                    // Keep just one hints pane there, including after hidden closes.
                    for duplicate in hints {
                        close_plugin_pane(duplicate.id);
                    }
                }
                if self.views != views {
                    self.views = views;
                    self.refresh();
                }
            }
            _ => {}
        }
        self.ready && self.visible
    }

    fn pipe(&mut self, message: PipeMessage) -> bool {
        if !self.controller
            && message.name == "hints-mode"
            && let Some((mode, rows)) = message.payload.and_then(|p| serde_json::from_str(&p).ok())
        {
            self.mode = mode;
            self.rows = rows;
            self.refresh();
        }
        self.ready && self.visible
    }

    fn render(&mut self, rows: usize, cols: usize) {
        let key_width = self.key_width();
        print_text_with_coordinates(
            Text::new(format!("{:?}", self.mode)).color_all(0),
            1,
            0,
            Some(cols.saturating_sub(2)),
            None,
        );
        for (y, (key, description)) in self.rows.iter().take(rows.saturating_sub(1)).enumerate() {
            let label = format!("{key:<key_width$}  {description}");
            print_text_with_coordinates(
                Text::new(label).color_range(3, 0..key.chars().count()),
                1,
                y + 1,
                Some(cols.saturating_sub(2)),
                None,
            );
        }
    }
}

impl Hints {
    fn key_width(&self) -> usize {
        self.rows
            .iter()
            .map(|(k, _)| k.chars().count())
            .max()
            .unwrap_or(0)
    }

    fn refresh(&mut self) {
        if !self.ready {
            return;
        }
        if self.controller {
            let payload = serde_json::to_string(&(self.mode, &self.rows)).unwrap();
            for id in &self.views {
                pipe_message_to_plugin(MessageToPlugin {
                    destination_plugin_id: Some(*id),
                    message_name: "hints-mode".into(),
                    message_payload: Some(payload.clone()),
                    ..Default::default()
                });
            }
            return;
        }
        let active = matches!(
            self.mode,
            InputMode::Normal
                | InputMode::Pane
                | InputMode::Tab
                | InputMode::Session
                | InputMode::Resize
                | InputMode::Scroll
        );
        if !active || self.rows.is_empty() {
            if self.visible {
                self.visible = false;
                hide_self();
            }
            return;
        }
        let pane = PaneId::Plugin(self.id);
        if !self.visible {
            self.visible = true;
            show_pane_with_id(pane, true, false); // leave input focused on the terminal
        }
        let key_width = self.key_width();
        let description_width = self
            .rows
            .iter()
            .map(|(_, d)| d.chars().count())
            .max()
            .unwrap_or(0);
        let width = (key_width + description_width + 6).min(self.size.1.saturating_sub(2));
        let height = (self.rows.len() + 3).min(self.size.0.saturating_sub(2));
        if let Some(coordinates) = FloatingPaneCoordinates::new(
            Some(self.size.1.saturating_sub(width + 1).to_string()),
            Some(self.size.0.saturating_sub(height + 1).to_string()),
            Some(width.to_string()),
            Some(height.to_string()),
            Some(true),
            Some(false),
        ) {
            change_floating_panes_coordinates(vec![(pane, coordinates)]);
        }
    }
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
            keys.push_str(&format!(" / {key}"));
        } else {
            groups.push((key.to_string(), description));
        }
    }
    groups
}

fn describe(action: &Action) -> String {
    match action {
        Action::SwitchToMode { input_mode } => match input_mode {
            InputMode::Locked => "Cancel / return to typing".into(),
            InputMode::Normal => "Leader".into(),
            InputMode::Tab => "Tabs".into(),
            InputMode::Pane => "Panes".into(),
            InputMode::Session => "Sessions".into(),
            InputMode::RenameTab => "Rename tab".into(),
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
        Action::NewFloatingPane {
            pane_name: Some(name),
            ..
        } => name.clone(),
        Action::TabNameInput { .. } => "Rename tab".into(),
        Action::GoToTab { .. } => "Go to tab".into(),
        Action::GoToPreviousTab => "Previous tab".into(),
        Action::GoToNextTab => "Next tab".into(),
        Action::ToggleTab => "Last tab".into(),
        Action::FocusLastPane => "Last pane".into(),
        Action::CloseTab => "Close tab".into(),
        Action::CloseFocus => "Close pane".into(),
        Action::ToggleFocusFullscreen => "Maximize / restore pane".into(),
        Action::ToggleFloatingPanes => "Show / hide floating panes".into(),
        Action::FocusGuestSession => "Control nested session".into(),
        Action::FocusHostSession => "Control parent session".into(),
        Action::ToggleHostFullscreen => "Maximize / restore nested session".into(),
        Action::Detach => "Detach session".into(),
        Action::Quit => "Quit session".into(),
        Action::EditScrollback { .. } => "Open scrollback in editor".into(),
        Action::KeybindPipe { name, .. } => {
            format!("Plugin: {}", name.as_deref().unwrap_or("message"))
        }
        action if action.launches_plugin("new-session") => "New session".into(),
        action if action.launches_plugin("find-tabs") => "Find tabs / panes / sessions".into(),
        action if action.launches_plugin("find-sessions") => "Find sessions".into(),
        action if action.launches_plugin("session-manager") => {
            "Find tabs / panes / sessions".into()
        }
        // New actions still appear without adding another menu entry here.
        action => format!("{action:?}")
            .split(['{', '('])
            .next()
            .unwrap_or("Action")
            .trim()
            .to_owned(),
    }
}
