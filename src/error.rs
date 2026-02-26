//! Error types for cloud-agent
//!
//! This module defines custom error types that make it easier to understand
//! what went wrong when something fails.

use thiserror::Error;

/// Main error type for cloud-agent operations
#[derive(Error, Debug)]
pub enum CloudAgentError {
    #[error("VM '{0}' not found")]
    VmNotFound(String),

    #[error("VM '{0}' already exists")]
    VmAlreadyExists(String),

    #[error("SSH key not found at '{0}'")]
    SshKeyNotFound(String),

    #[error("Agent '{0}' not found. Available agents: {1}")]
    AgentNotFound(String, String),

    #[error("Failed to detect public IP address")]
    IpDetectionFailed,

    #[error("GCP project not configured. Run: gcloud config set project PROJECT_ID")]
    GcpProjectNotConfigured,

    #[error("Terraform command failed: {0}")]
    TerraformFailed(String),

    #[error("Git operation failed: {0}")]
    GitFailed(String),

    #[error("SSH connection failed: {0}")]
    SshFailed(String),

    #[error("Agent '{0}' is not logged in. {1}")]
    AgentNotLoggedIn(String, String),

    #[error("Invalid repository URL: {0}")]
    InvalidRepoUrl(String),

    #[error("Configuration error: {0}")]
    ConfigError(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("HTTP request failed: {0}")]
    Http(#[from] reqwest::Error),
}

/// Result type alias for cloud-agent operations
pub type Result<T> = std::result::Result<T, CloudAgentError>;

