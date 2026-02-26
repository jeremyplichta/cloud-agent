//! Configuration management for cloud-agent
//!
//! This module handles loading and managing configuration from various sources:
//! - Command-line arguments
//! - Environment variables
//! - Default values

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use crate::cli::Args;
use crate::error::CloudAgentError;

/// Main configuration struct
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Agent to use (auggie, claude, codex)
    pub agent: String,

    /// GCP project ID
    pub project_id: String,

    /// GCP region
    pub region: String,

    /// GCP zone
    pub zone: String,

    /// VM machine type
    pub machine_type: String,

    /// VM name
    pub vm_name: String,

    /// Owner (derived from username)
    pub owner: String,

    /// SSH username for the VM
    pub ssh_username: String,

    /// Skip deletion label
    pub skip_deletion: String,

    /// GKE cluster name (optional)
    pub cluster_name: Option<String>,

    /// Cluster zone
    pub cluster_zone: String,

    /// Path to SSH private key
    pub ssh_key: Option<PathBuf>,

    /// GitHub personal access token
    pub github_token: Option<String>,

    /// Permissions for VM service account
    pub permissions: Vec<String>,

    /// Additional IP to whitelist
    pub additional_ip: Option<String>,

    /// Company domain
    pub company: Option<String>,
}

impl Config {
    /// Create configuration from CLI arguments
    pub fn from_args(args: &Args) -> Result<Self> {
        // Get GCP project ID
        let project_id = get_gcp_project()?;

        // Derive owner and VM name
        let owner = derive_owner(args.username.as_deref(), args.company.as_deref())?;
        let vm_name = derive_vm_name(&owner);
        let ssh_username = owner.replace('_', "-");

        // Parse permissions
        let permissions = args
            .permissions
            .as_ref()
            .map(|p| p.split(',').map(|s| s.trim().to_string()).collect())
            .unwrap_or_default();

        // Detect SSH key
        let ssh_key = args.ssh_key.as_ref().map(PathBuf::from).or_else(detect_ssh_key);

        Ok(Config {
            agent: args.agent.clone(),
            project_id,
            region: "us-central1".to_string(),
            zone: args.zone.clone(),
            machine_type: args.machine_type.clone(),
            vm_name,
            owner,
            ssh_username,
            skip_deletion: args.skip_deletion.clone(),
            cluster_name: args.cluster_name.clone(),
            cluster_zone: args.cluster_name.as_ref().map(|_| args.zone.clone()).unwrap_or_else(|| args.zone.clone()),
            ssh_key,
            github_token: args.github_token.clone(),
            permissions,
            additional_ip: args.additional_ip.clone(),
            company: args.company.clone(),
        })
    }
}

/// Get GCP project ID from gcloud config
fn get_gcp_project() -> Result<String> {
    let output = std::process::Command::new("gcloud")
        .args(["config", "get-value", "project"])
        .output()?;

    if !output.status.success() {
        return Err(CloudAgentError::GcpProjectNotConfigured.into());
    }

    let project_id = String::from_utf8(output.stdout)?
        .trim()
        .to_string();

    if project_id.is_empty() {
        return Err(CloudAgentError::GcpProjectNotConfigured.into());
    }

    Ok(project_id)
}

/// Derive owner from username and company
fn derive_owner(username: Option<&str>, company: Option<&str>) -> Result<String> {
    let base = if let Some(user) = username {
        user.to_string()
    } else {
        // Get from $USER environment variable
        std::env::var("USER")
            .map_err(|_| CloudAgentError::ConfigError("USER environment variable not set".to_string()))?
    };

    let mut owner = base.replace('.', "_").replace('-', "_").to_lowercase();

    if let Some(comp) = company {
        let company_suffix = comp.replace('.', "_").replace('-', "_").to_lowercase();
        owner = format!("{}_{}", owner, company_suffix);
    }

    Ok(owner)
}

/// Derive VM name from owner
fn derive_vm_name(owner: &str) -> String {
    format!("{}-cloud-agent", owner.replace('_', "-"))
}

/// Detect SSH key from common locations
fn detect_ssh_key() -> Option<PathBuf> {
    let home = dirs::home_dir()?;
    let candidates = [
        "cloud-auggie",
        "cloud-agent",
        "id_ed25519",
        "id_rsa",
    ];

    for candidate in &candidates {
        let path = home.join(".ssh").join(candidate);
        if path.exists() {
            return Some(path);
        }
    }

    None
}

