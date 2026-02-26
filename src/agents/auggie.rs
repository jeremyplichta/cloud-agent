//! Auggie (Augment Code) agent implementation

use std::path::PathBuf;
use crate::agents::Agent;
use crate::utils;

pub struct Auggie;

impl Agent for Auggie {
    fn display_name(&self) -> &str {
        "Auggie (Augment Code)"
    }

    fn command(&self) -> &str {
        "auggie"
    }

    fn install_command(&self) -> &str {
        "npm install -g @augmentcode/auggie"
    }

    fn check_local(&self) -> bool {
        utils::command_exists("auggie")
    }

    fn check_logged_in(&self) -> bool {
        // Check if session.json exists
        if let Some(home) = dirs::home_dir() {
            home.join(".augment/session.json").exists()
        } else {
            false
        }
    }

    fn login_instructions(&self) -> String {
        "Run 'auggie login' to authenticate".to_string()
    }

    fn credentials_path(&self) -> Option<PathBuf> {
        dirs::home_dir().map(|h| h.join(".augment/session.json"))
    }

    fn remote_credentials_path(&self) -> &str {
        "~/.augment/session.json"
    }
}

