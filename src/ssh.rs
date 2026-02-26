//! SSH operations for cloud-agent
//!
//! This module handles SSH connections, file transfers, and remote command execution.

use anyhow::Result;
use std::path::Path;
use std::process::Command;

use crate::config::Config;
use crate::error::CloudAgentError;
use crate::utils;

/// SSH client for managing VM connections
pub struct SshClient {
    config: Config,
    vm_ip: String,
}

impl SshClient {
    /// Create a new SSH client
    pub fn new(config: Config, vm_ip: String) -> Self {
        Self { config, vm_ip }
    }

    /// Execute a command on the VM via SSH
    pub fn execute(&self, command: &str) -> Result<String> {
        let ssh_key = self.config.ssh_key.as_ref()
            .ok_or_else(|| CloudAgentError::SshKeyNotFound("No SSH key configured".to_string()))?;

        let output = Command::new("ssh")
            .args([
                "-i", ssh_key.to_str().unwrap(),
                "-o", "StrictHostKeyChecking=accept-new",
                "-o", "ConnectTimeout=10",
                &format!("{}@{}", self.config.ssh_username, self.vm_ip),
                command,
            ])
            .output()?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(CloudAgentError::SshFailed(stderr.to_string()).into());
        }

        Ok(String::from_utf8(output.stdout)?.trim().to_string())
    }

    /// Execute a command on the VM via SSH (streaming output)
    pub fn execute_streaming(&self, command: &str) -> Result<()> {
        let ssh_key = self.config.ssh_key.as_ref()
            .ok_or_else(|| CloudAgentError::SshKeyNotFound("No SSH key configured".to_string()))?;

        let status = Command::new("ssh")
            .args([
                "-i", ssh_key.to_str().unwrap(),
                "-o", "StrictHostKeyChecking=accept-new",
                "-o", "ConnectTimeout=10",
                &format!("{}@{}", self.config.ssh_username, self.vm_ip),
                command,
            ])
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::SshFailed(format!("Command failed with status: {}", status)).into());
        }

        Ok(())
    }

    /// Copy a file to the VM
    pub fn copy_to_vm(&self, local_path: &Path, remote_path: &str) -> Result<()> {
        let ssh_key = self.config.ssh_key.as_ref()
            .ok_or_else(|| CloudAgentError::SshKeyNotFound("No SSH key configured".to_string()))?;

        let status = Command::new("scp")
            .args([
                "-i", ssh_key.to_str().unwrap(),
                "-o", "StrictHostKeyChecking=accept-new",
                "-o", "ConnectTimeout=10",
                local_path.to_str().unwrap(),
                &format!("{}@{}:{}", self.config.ssh_username, self.vm_ip, remote_path),
            ])
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::SshFailed("SCP failed".to_string()).into());
        }

        Ok(())
    }

    /// Copy a file from the VM
    pub fn copy_from_vm(&self, remote_path: &str, local_path: &Path) -> Result<()> {
        let ssh_key = self.config.ssh_key.as_ref()
            .ok_or_else(|| CloudAgentError::SshKeyNotFound("No SSH key configured".to_string()))?;

        let status = Command::new("scp")
            .args([
                "-i", ssh_key.to_str().unwrap(),
                "-o", "StrictHostKeyChecking=accept-new",
                "-o", "ConnectTimeout=10",
                &format!("{}@{}:{}", self.config.ssh_username, self.vm_ip, remote_path),
                local_path.to_str().unwrap(),
            ])
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::SshFailed("SCP failed".to_string()).into());
        }

        Ok(())
    }

    /// Open an interactive SSH session with tmux
    pub fn interactive_session(&self) -> Result<()> {
        let ssh_key = self.config.ssh_key.as_ref()
            .ok_or_else(|| CloudAgentError::SshKeyNotFound("No SSH key configured".to_string()))?;

        utils::log(&format!("Connecting to {} ({}) as {}...", 
            self.config.vm_name, self.vm_ip, self.config.ssh_username));
        utils::log(&format!("Using SSH key: {}", ssh_key.display()));

        let status = Command::new("ssh")
            .args([
                "-i", ssh_key.to_str().unwrap(),
                "-o", "StrictHostKeyChecking=accept-new",
                &format!("{}@{}", self.config.ssh_username, self.vm_ip),
                "-t",
                "tmux attach-session 2>/dev/null || tmux new-session",
            ])
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::SshFailed("SSH session failed".to_string()).into());
        }

        Ok(())
    }

    /// Copy files with 'vm:' prefix support
    pub fn scp_with_prefix(&self, src: &str, dst: &str) -> Result<()> {
        let ssh_key = self.config.ssh_key.as_ref()
            .ok_or_else(|| CloudAgentError::SshKeyNotFound("No SSH key configured".to_string()))?;

        // Replace 'vm:' prefix with user@ip:
        let remote_prefix = format!("{}@{}:", self.config.ssh_username, self.vm_ip);
        let src_resolved = src.replace("vm:", &remote_prefix);
        let dst_resolved = dst.replace("vm:", &remote_prefix);

        utils::log("Copying files...");
        let status = Command::new("scp")
            .args([
                "-i", ssh_key.to_str().unwrap(),
                "-o", "StrictHostKeyChecking=accept-new",
                "-r",
                &src_resolved,
                &dst_resolved,
            ])
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::SshFailed("SCP failed".to_string()).into());
        }

        utils::log_success("Copy complete");
        Ok(())
    }
}

