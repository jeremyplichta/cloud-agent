//! Git operations for cloud-agent
//!
//! This module handles git-related operations like detecting the current
//! repository and validating repository URLs.

use anyhow::Result;
use std::process::Command;

use crate::error::CloudAgentError;

/// Detect the current git repository's origin URL
pub fn detect_current_repo() -> Result<Vec<String>> {
    // Check if we're in a git repository
    let is_git_repo = Command::new("git")
        .args(["rev-parse", "--is-inside-work-tree"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if !is_git_repo {
        return Err(CloudAgentError::ConfigError(
            "Not in a git repository. Please specify a repository URL or run from a git directory.".to_string()
        ).into());
    }

    // Get the origin URL
    let output = Command::new("git")
        .args(["remote", "get-url", "origin"])
        .output()?;

    if !output.status.success() {
        return Err(CloudAgentError::ConfigError(
            "No 'origin' remote found in current git repository.".to_string()
        ).into());
    }

    let url = String::from_utf8(output.stdout)?
        .trim()
        .to_string();

    if url.is_empty() {
        return Err(CloudAgentError::ConfigError(
            "Origin remote URL is empty.".to_string()
        ).into());
    }

    crate::utils::log(&format!("Auto-detected repo from current directory: {}", url));
    Ok(vec![url])
}

/// Validate a repository URL
pub fn validate_repo_url(url: &str) -> Result<()> {
    // Check if it's a valid SSH or HTTPS URL
    if url.starts_with("git@") || url.starts_with("https://") || url.starts_with("http://") {
        Ok(())
    } else {
        Err(CloudAgentError::InvalidRepoUrl(url.to_string()).into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_repo_url() {
        assert!(validate_repo_url("git@github.com:org/repo.git").is_ok());
        assert!(validate_repo_url("https://github.com/org/repo.git").is_ok());
        assert!(validate_repo_url("invalid-url").is_err());
    }
}

