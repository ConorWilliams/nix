use std::collections::BTreeMap;
use zellij_tile::prelude::*;

#[derive(Default)]
struct Anon(bool);
register_plugin!(Anon);

impl ZellijPlugin for Anon {
    fn load(&mut self, _: BTreeMap<String, String>) {
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
        subscribe(&[EventType::SessionUpdate]);
    }

    fn update(&mut self, event: Event) -> bool {
        if let Event::SessionUpdate(sessions, _) = event {
            for session in sessions {
                if session.is_current_session {
                    // Startup can report zero clients before the first attach.
                    self.0 |= session.connected_clients > 0;
                    // Server-side cleanup survives a killed client. Renaming opts out.
                    if self.0 && session.name.starts_with("anon-") && session.connected_clients == 0
                    {
                        let _ = kill_sessions(&[session.name]);
                    }
                }
            }
        }
        false
    }
}
