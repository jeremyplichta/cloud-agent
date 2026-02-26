//! Codex (OpenAI) agent implementation

use std::path::PathBuf;
use crate::agents::Agent;
use crate::utils;

pub struct Codex;

impl Agent for Codex {
    fn display_name(&self) -> &str {
        "Codex (OpenAI)"
    }

    fn command(&self) -> &str {
        "codex"
    }

    fn install_command(&self) -> &str {
        "npm install -g @openai/codex"
    }

    fn check_local(&self) -> bool {
        utils::command_exists("codex")
    }

    fn check_logged_in(&self) -> bool {
        // Check if config.toml exists
        if let Some(home) = dirs::home_dir() {
            home.join(".codex/config.toml").exists()
        } else {
            false
        }
    }

    fn login_instructions(&self) -> String {
        "Run 'codex' to authenticate".to_string()
    }

    fn credentials_path(&self) -> Option<PathBuf> {
        dirs::home_dir().map(|h| h.join(".codex/config.toml"))
    }

    fn remote_credentials_path(&self) -> &str {
        "~/.codex/config.toml"
    }
}

