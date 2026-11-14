//! Quits the session, saved as it is: on a `quit` message (s q y), saves
//! it, then ends it for every client, to resurrect later. Zellij's own
//! Quit action only leaves, and saves nothing.
//!
//! After cristiand391/zj-quit, but with no pane: the confirmation is the
//! next key (y), in a mode of its own. A pane open when the session is saved
//! would come back with it, to ask again.

use std::collections::BTreeMap;
use zellij_tile::prelude::*;

#[derive(Default)]
struct Quit {
    ready: bool,
}
register_plugin!(Quit);

impl ZellijPlugin for Quit {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        subscribe(&[EventType::PermissionRequestResult]);
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        if let Event::PermissionRequestResult(PermissionStatus::Granted) = event {
            self.ready = true;
        }
        false
    }

    fn pipe(&mut self, message: PipeMessage) -> bool {
        if self.ready && message.name == "quit" {
            let _ = save_session();
            if let Ok(sessions) = get_session_list() {
                let current: Vec<&str> = sessions
                    .live_sessions
                    .iter()
                    .filter(|s| s.is_current_session)
                    .map(|s| s.name.as_str())
                    .collect();
                let _ = kill_sessions(&current);
            }
        }
        false
    }
}
