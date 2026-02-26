//! Utility functions for cloud-agent
//!
//! This module contains helper functions used throughout the application.

use anyhow::Result;
use chrono::Local;
use std::process::Command;

use crate::error::CloudAgentError;

/// Log a message with timestamp
pub fn log(message: &str) {
    let timestamp = Local::now().format("%H:%M:%S");
    println!("[{}] {}", timestamp, message);
}

/// Log an error message
pub fn log_error(message: &str) {
    let timestamp = Local::now().format("%H:%M:%S");
    eprintln!("[{}] ❌ {}", timestamp, message);
}

/// Log a success message
pub fn log_success(message: &str) {
    let timestamp = Local::now().format("%H:%M:%S");
    println!("[{}] ✅ {}", timestamp, message);
}

/// Log a warning message
pub fn log_warning(message: &str) {
    let timestamp = Local::now().format("%H:%M:%S");
    println!("[{}] ⚠️  {}", timestamp, message);
}

/// Detect public IPv4 address
pub async fn detect_public_ipv4() -> Result<String> {
    // Try multiple services for reliability
    let services = [
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://icanhazip.com",
    ];

    for service in &services {
        if let Ok(response) = reqwest::get(*service).await {
            if let Ok(ip) = response.text().await {
                let ip = ip.trim();
                if !ip.is_empty() && is_valid_ipv4(ip) {
                    log(&format!("✓ Your IPv4 address: {}", ip));
                    return Ok(format!("{}/32", ip));
                }
            }
        }
    }

    Err(CloudAgentError::IpDetectionFailed.into())
}

/// Check if a string is a valid IPv4 address
fn is_valid_ipv4(ip: &str) -> bool {
    ip.split('.')
        .filter_map(|s| s.parse::<u8>().ok())
        .count() == 4
}

/// Check if a command exists in PATH
pub fn command_exists(cmd: &str) -> bool {
    which::which(cmd).is_ok()
}

/// Run a command and return its output
pub fn run_command(cmd: &str, args: &[&str]) -> Result<String> {
    let output = Command::new(cmd)
        .args(args)
        .output()?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("Command failed: {}", stderr));
    }

    Ok(String::from_utf8(output.stdout)?.trim().to_string())
}

/// Run a command and stream its output
pub fn run_command_streaming(cmd: &str, args: &[&str]) -> Result<()> {
    let status = Command::new(cmd)
        .args(args)
        .status()?;

    if !status.success() {
        return Err(anyhow::anyhow!("Command failed with status: {}", status));
    }

    Ok(())
}

/// Extract repository name from URL
pub fn extract_repo_name(url: &str) -> Result<String> {
    // Handle both SSH and HTTPS URLs
    // git@github.com:org/repo.git -> repo
    // https://github.com/org/repo.git -> repo
    
    let name = url
        .rsplit('/')
        .next()
        .ok_or_else(|| CloudAgentError::InvalidRepoUrl(url.to_string()))?
        .trim_end_matches(".git");

    if name.is_empty() {
        return Err(CloudAgentError::InvalidRepoUrl(url.to_string()).into());
    }

    Ok(name.to_string())
}

/// Print a fancy header
pub fn print_header(title: &str) {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  {}  ║", title);
    println!("╚══════════════════════════════════════════════════════════════╝");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_valid_ipv4() {
        assert!(is_valid_ipv4("192.168.1.1"));
        assert!(is_valid_ipv4("8.8.8.8"));
        assert!(!is_valid_ipv4("256.1.1.1"));
        assert!(!is_valid_ipv4("not.an.ip.address"));
    }

    #[test]
    fn test_extract_repo_name() {
        assert_eq!(
            extract_repo_name("git@github.com:org/repo.git").unwrap(),
            "repo"
        );
        assert_eq!(
            extract_repo_name("https://github.com/org/repo.git").unwrap(),
            "repo"
        );
        assert_eq!(
            extract_repo_name("https://github.com/org/repo").unwrap(),
            "repo"
        );
    }
}

