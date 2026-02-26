//! Claude Code (Anthropic) agent implementation

use std::path::PathBuf;
use crate::agents::Agent;
use crate::utils;

pub struct Claude;

impl Agent for Claude {
    fn display_name(&self) -> &str {
        "Claude Code (Anthropic)"
    }

    fn command(&self) -> &str {
        "claude"
    }

    fn install_command(&self) -> &str {
        "npm install -g @anthropic-ai/claude-code"
    }

    fn check_local(&self) -> bool {
        utils::command_exists("claude")
    }

    fn check_logged_in(&self) -> bool {
        // Check if .claude.json exists
        if let Some(home) = dirs::home_dir() {
            home.join(".claude.json").exists()
        } else {
            false
        }
    }

    fn login_instructions(&self) -> String {
        "Run 'claude' to authenticate".to_string()
    }

    fn credentials_path(&self) -> Option<PathBuf> {
        dirs::home_dir().map(|h| h.join(".claude.json"))
    }

    fn remote_credentials_path(&self) -> &str {
        "~/.claude.json"
    }
}

