//! Agent management for cloud-agent
//!
//! This module handles different AI coding agents (Auggie, Claude, Codex).
//! Each agent has its own configuration and requirements.

mod auggie;
mod claude;
mod codex;

use anyhow::Result;
use std::path::PathBuf;

use crate::config::Config;
use crate::error::CloudAgentError;
use crate::utils;

/// Trait for agent implementations
pub trait Agent {
    /// Get the display name of the agent
    fn display_name(&self) -> &str;

    /// Get the command to run the agent
    fn command(&self) -> &str;

    /// Get the install command for the agent
    fn install_command(&self) -> &str;

    /// Check if the agent CLI is installed locally
    fn check_local(&self) -> bool;

    /// Check if the user is logged in to the agent
    fn check_logged_in(&self) -> bool;

    /// Get login instructions
    fn login_instructions(&self) -> String;

    /// Get the path to the agent's credentials file
    fn credentials_path(&self) -> Option<PathBuf>;

    /// Get the remote credentials path on the VM
    fn remote_credentials_path(&self) -> &str;
}

/// Agent manager that handles all agent operations
pub struct AgentManager {
    agent: Box<dyn Agent>,
}

impl AgentManager {
    /// Create a new agent manager
    pub fn new(config: Config) -> Result<Self> {
        let agent: Box<dyn Agent> = match config.agent.as_str() {
            "auggie" => Box::new(auggie::Auggie),
            "claude" => Box::new(claude::Claude),
            "codex" => Box::new(codex::Codex),
            _ => {
                let available = "auggie, claude, codex";
                return Err(CloudAgentError::AgentNotFound(config.agent, available.to_string()).into());
            }
        };

        Ok(Self { agent })
    }

    /// Check agent prerequisites (installed and logged in)
    pub async fn check_prerequisites(&self) -> Result<()> {
        utils::log(&format!("Checking {} prerequisites...", self.agent.display_name()));

        if !self.agent.check_local() {
            return Err(CloudAgentError::AgentNotLoggedIn(
                self.agent.display_name().to_string(),
                format!("Install it with: {}", self.agent.install_command()),
            ).into());
        }

        if !self.agent.check_logged_in() {
            return Err(CloudAgentError::AgentNotLoggedIn(
                self.agent.display_name().to_string(),
                self.agent.login_instructions(),
            ).into());
        }

        utils::log_success(&format!("{} CLI found and logged in", self.agent.display_name()));
        Ok(())
    }

    /// Get the agent's display name
    pub fn display_name(&self) -> &str {
        self.agent.display_name()
    }

    /// Get the command to run the agent
    pub fn command(&self) -> &str {
        self.agent.command()
    }

    /// Get the agent's credentials path
    pub fn credentials_path(&self) -> Option<PathBuf> {
        self.agent.credentials_path()
    }

    /// Get the remote credentials path
    pub fn remote_credentials_path(&self) -> &str {
        self.agent.remote_credentials_path()
    }
}

/// List all available agents
pub fn list_agents() -> Vec<&'static str> {
    vec!["auggie", "claude", "codex"]
}

