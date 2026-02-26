//! Google Cloud Platform operations for cloud-agent
//!
//! This module handles VM creation, management, and Terraform operations.

use anyhow::Result;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::io::Write;

use crate::config::Config;
use crate::error::CloudAgentError;
use crate::ssh::SshClient;
use crate::utils;

/// VM manager for GCP operations
pub struct VmManager {
    config: Config,
    script_dir: PathBuf,
}

impl VmManager {
    /// Create a new VM manager
    pub fn new(config: Config) -> Self {
        let script_dir = std::env::current_dir()
            .expect("Failed to get current directory");

        Self { config, script_dir }
    }

    /// List all cloud-agent VMs
    pub async fn list(&self) -> Result<()> {
        utils::log("Listing cloud-agent VMs...");
        
        let status = Command::new("gcloud")
            .args([
                "compute", "instances", "list",
                "--filter=labels.purpose=cloud-agent",
                "--format=table(name,zone,status,labels.owner,labels.skip_deletion,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)",
            ])
            .status()?;

        if !status.success() {
            return Err(anyhow::anyhow!("Failed to list VMs"));
        }

        Ok(())
    }

    /// Start a stopped VM
    pub async fn start(&self) -> Result<()> {
        utils::log(&format!("Starting VM: {}...", self.config.vm_name));
        
        let status = Command::new("gcloud")
            .args([
                "compute", "instances", "start",
                &self.config.vm_name,
                &format!("--zone={}", self.config.zone),
            ])
            .status()?;

        if !status.success() {
            return Err(anyhow::anyhow!("Failed to start VM"));
        }

        utils::log_success("VM started");
        Ok(())
    }

    /// Stop a running VM
    pub async fn stop(&self) -> Result<()> {
        utils::log(&format!("Stopping VM: {}...", self.config.vm_name));
        
        let status = Command::new("gcloud")
            .args([
                "compute", "instances", "stop",
                &self.config.vm_name,
                &format!("--zone={}", self.config.zone),
            ])
            .status()?;

        if !status.success() {
            return Err(anyhow::anyhow!("Failed to stop VM"));
        }

        utils::log_success("VM stopped");
        Ok(())
    }

    /// Terminate (delete) a VM
    pub async fn terminate(&self) -> Result<()> {
        utils::log_warning("Terminating VM and cleaning up resources...");
        
        print!("Are you sure? [y/N] ");
        std::io::stdout().flush()?;
        
        let mut input = String::new();
        std::io::stdin().read_line(&mut input)?;
        
        if !input.trim().eq_ignore_ascii_case("y") {
            utils::log("Cancelled");
            return Ok(());
        }

        let tfstate_path = self.script_dir.join("terraform.tfstate");
        if tfstate_path.exists() {
            utils::log("Running terraform destroy...");
            let status = Command::new("terraform")
                .args(["destroy", "-auto-approve"])
                .current_dir(&self.script_dir)
                .status()?;

            if !status.success() {
                return Err(CloudAgentError::TerraformFailed("destroy failed".to_string()).into());
            }

            utils::log_success("All resources destroyed");
        } else {
            utils::log("No terraform state found, using gcloud to delete VM...");
            let status = Command::new("gcloud")
                .args([
                    "compute", "instances", "delete",
                    &self.config.vm_name,
                    &format!("--zone={}", self.config.zone),
                    "--quiet",
                ])
                .status()?;

            if !status.success() {
                return Err(anyhow::anyhow!("Failed to delete VM"));
            }

            utils::log_success("VM terminated");
        }

        Ok(())
    }

    /// SSH into the VM
    pub async fn ssh(&self) -> Result<()> {
        let vm_ip = self.get_vm_ip().await?;
        let ssh_client = SshClient::new(self.config.clone(), vm_ip);
        ssh_client.interactive_session()?;
        Ok(())
    }

    /// Copy files to/from VM
    pub async fn scp(&self, src: &str, dst: &str) -> Result<()> {
        if src.is_empty() || dst.is_empty() {
            utils::log_error("Usage: ca scp <src> <dst>");
            utils::log("  Use 'vm:' prefix for remote paths");
            utils::log("  Examples:");
            utils::log("    ca scp ./local-file.txt vm:/workspace/  # Upload to VM");
            utils::log("    ca scp vm:/workspace/file.txt ./        # Download from VM");
            return Err(anyhow::anyhow!("Invalid arguments"));
        }

        let vm_ip = self.get_vm_ip().await?;
        let ssh_client = SshClient::new(self.config.clone(), vm_ip);
        ssh_client.scp_with_prefix(src, dst)?;
        Ok(())
    }

    /// Get VM IP address
    async fn get_vm_ip(&self) -> Result<String> {
        // Try terraform state first
        let tfstate_path = self.script_dir.join("terraform.tfstate");
        if tfstate_path.exists() {
            let output = Command::new("terraform")
                .args(["output", "-raw", "cloud_agent_ip"])
                .current_dir(&self.script_dir)
                .output()?;

            if output.status.success() {
                let ip = String::from_utf8(output.stdout)?.trim().to_string();
                if !ip.is_empty() {
                    return Ok(ip);
                }
            }
        }

        // Fallback to gcloud
        let output = Command::new("gcloud")
            .args([
                "compute", "instances", "describe",
                &self.config.vm_name,
                &format!("--zone={}", self.config.zone),
                "--format=value(networkInterfaces[0].accessConfigs[0].natIP)",
            ])
            .output()?;

        if !output.status.success() {
            return Err(CloudAgentError::VmNotFound(self.config.vm_name.clone()).into());
        }

        let ip = String::from_utf8(output.stdout)?.trim().to_string();
        if ip.is_empty() {
            return Err(anyhow::anyhow!("Could not determine VM IP address"));
        }

        Ok(ip)
    }

    /// Check if VM exists
    async fn vm_exists(&self) -> Result<bool> {
        // Check terraform state first
        let tfstate_path = self.script_dir.join("terraform.tfstate");
        if tfstate_path.exists() {
            let output = Command::new("terraform")
                .args(["output", "-raw", "vm_name"])
                .current_dir(&self.script_dir)
                .output()?;

            if output.status.success() {
                let vm_name = String::from_utf8(output.stdout)?.trim().to_string();
                if vm_name == self.config.vm_name {
                    return Ok(true);
                }
            }
        }

        // Fallback to gcloud
        let output = Command::new("gcloud")
            .args([
                "compute", "instances", "list",
                &format!("--filter=name={}", self.config.vm_name),
                "--format=value(name)",
            ])
            .output()?;

        Ok(output.status.success() && !String::from_utf8(output.stdout)?.trim().is_empty())
    }

    /// Apply terraform configuration
    pub async fn apply_terraform(&self) -> Result<()> {
        utils::log("Re-applying terraform configuration...");

        let tfstate_path = self.script_dir.join("terraform.tfstate");
        if !tfstate_path.exists() {
            return Err(anyhow::anyhow!(
                "No terraform state found. Create VM first with: ca <repo>"
            ));
        }

        // Generate terraform.tfvars
        self.generate_tfvars().await?;

        // Apply terraform
        utils::log("");
        utils::log("Applying Terraform...");
        let status = Command::new("terraform")
            .args(["apply", "-auto-approve"])
            .current_dir(&self.script_dir)
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::TerraformFailed("apply failed".to_string()).into());
        }

        utils::log("");
        utils::log_success("Terraform apply complete!");
        Ok(())
    }

    /// Create VM
    pub async fn create_vm(&self, force: bool) -> Result<()> {
        if !force && self.vm_exists().await? {
            utils::log(&format!("✓ Cloud Agent VM already exists: {}", self.config.vm_name));
            return Ok(());
        }

        utils::print_header("🐕 CREATING CLOUD AGENT VM");

        // Generate terraform.tfvars
        self.generate_tfvars().await?;

        // Initialize terraform
        utils::log("");
        utils::log("Initializing Terraform...");
        let status = Command::new("terraform")
            .args(["init", "-input=false"])
            .current_dir(&self.script_dir)
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::TerraformFailed("init failed".to_string()).into());
        }

        // Apply terraform
        utils::log("");
        utils::log(&format!("Applying Terraform (creating {} VM)...", self.config.vm_name));
        let status = Command::new("terraform")
            .args(["apply", "-auto-approve"])
            .current_dir(&self.script_dir)
            .status()?;

        if !status.success() {
            return Err(CloudAgentError::TerraformFailed("apply failed".to_string()).into());
        }

        let vm_ip = self.get_vm_ip().await?;
        utils::log("");
        utils::log_success("Cloud Agent VM created!");
        utils::log(&format!("   Name: {}", self.config.vm_name));
        utils::log(&format!("   External IP: {}", vm_ip));

        utils::log("");
        utils::log("Waiting 90s for VM to boot and run startup script...");
        tokio::time::sleep(tokio::time::Duration::from_secs(90)).await;

        Ok(())
    }

    /// Generate terraform.tfvars file
    async fn generate_tfvars(&self) -> Result<()> {
        utils::log("Generating terraform.tfvars...");

        // Detect public IP
        let allowed_ips = self.get_allowed_ips().await?;

        // Get SSH public key if available
        let (ssh_username, ssh_public_key) = self.get_ssh_config()?;

        // Format permissions as Terraform list
        let permissions_tf = if self.config.permissions.is_empty() {
            "[]".to_string()
        } else {
            format!("[\"{}\"]", self.config.permissions.join("\", \""))
        };

        // Format allowed IPs as Terraform list
        let allowed_ips_tf = format!("[\"{}\"]", allowed_ips.join("\", \""));

        // Write terraform.tfvars
        let tfvars_content = format!(
            r#"project_id     = "{}"
region         = "{}"
zone           = "{}"
machine_type   = "{}"
cluster_name   = "{}"
cluster_zone   = "{}"
vm_name        = "{}"
owner          = "{}"
skip_deletion  = "{}"
permissions    = {}
allowed_ips    = {}
ssh_username   = "{}"
ssh_public_key = "{}"
"#,
            self.config.project_id,
            self.config.region,
            self.config.zone,
            self.config.machine_type,
            self.config.cluster_name.as_deref().unwrap_or(""),
            self.config.cluster_zone,
            self.config.vm_name,
            self.config.owner,
            self.config.skip_deletion,
            permissions_tf,
            allowed_ips_tf,
            ssh_username,
            ssh_public_key,
        );

        let tfvars_path = self.script_dir.join("terraform.tfvars");
        fs::write(&tfvars_path, tfvars_content)?;

        Ok(())
    }

    /// Get allowed IPs for firewall rules
    async fn get_allowed_ips(&self) -> Result<Vec<String>> {
        utils::log("Detecting your public IP addresses...");

        let mut ips = vec![utils::detect_public_ipv4().await?];

        // Add additional IP if specified
        if let Some(additional_ip) = &self.config.additional_ip {
            let ip_with_cidr = if additional_ip.contains('/') {
                additional_ip.clone()
            } else {
                format!("{}/32", additional_ip)
            };
            ips.push(ip_with_cidr.clone());
            utils::log(&format!("✓ Additional whitelisted IP: {}", ip_with_cidr));
        }

        utils::log(&format!("✓ Firewall will allow SSH from: {}", ips.join(", ")));
        Ok(ips)
    }

    /// Get SSH configuration (username and public key)
    fn get_ssh_config(&self) -> Result<(String, String)> {
        if let Some(ssh_key) = &self.config.ssh_key {
            let pub_key_path = ssh_key.with_extension("pub");
            if pub_key_path.exists() {
                let public_key = fs::read_to_string(&pub_key_path)?;
                utils::log(&format!("✓ SSH will be secured for user: {}", self.config.ssh_username));
                utils::log(&format!("✓ Using public key from: {}", pub_key_path.display()));
                return Ok((self.config.ssh_username.clone(), public_key.trim().to_string()));
            }
        }

        utils::log_warning("No SSH public key found. SSH will not be hardened to a specific user.");
        Ok((String::new(), String::new()))
    }

    /// Deploy repositories to the VM
    pub async fn deploy_repos(&self, repos: &[String], skip_creds: bool) -> Result<()> {
        if !self.vm_exists().await? {
            return Err(CloudAgentError::VmNotFound(self.config.vm_name.clone()).into());
        }

        let vm_ip = self.get_vm_ip().await?;
        let ssh_client = SshClient::new(self.config.clone(), vm_ip);

        // Transfer credentials if not skipped
        if !skip_creds {
            self.transfer_credentials(&ssh_client).await?;
        }

        // Clone repositories
        if !repos.is_empty() {
            self.clone_repos(&ssh_client, repos).await?;
        }

        self.print_success_message(&ssh_client).await?;
        Ok(())
    }

    /// Full deployment (create VM if needed, then deploy repos)
    pub async fn full_deploy(&self, repos: &[String]) -> Result<()> {
        utils::print_header("🐕 CLOUD AGENT DEPLOYMENT");
        utils::log(&format!("VM name: {}", self.config.vm_name));
        utils::log(&format!("Owner: {}", self.config.owner));

        // Create VM if it doesn't exist
        if !self.vm_exists().await? {
            self.create_vm(false).await?;
        } else {
            utils::log(&format!("✓ Cloud Agent VM already exists: {}", self.config.vm_name));
        }

        // Deploy repos
        self.deploy_repos(repos, false).await?;

        Ok(())
    }

    /// Transfer credentials to the VM
    async fn transfer_credentials(&self, ssh_client: &SshClient) -> Result<()> {
        utils::log("");
        utils::log("Configuring credentials on VM...");

        // Create .ssh directory
        ssh_client.execute("mkdir -p ~/.ssh && chmod 700 ~/.ssh")?;

        // Transfer SSH key for GitHub
        if let Some(ssh_key) = &self.config.ssh_key {
            utils::log("Transferring GitHub SSH key...");

            ssh_client.copy_to_vm(ssh_key, "~/.ssh/id_ed25519")?;

            let pub_key = ssh_key.with_extension("pub");
            if pub_key.exists() {
                ssh_client.copy_to_vm(&pub_key, "~/.ssh/id_ed25519.pub")?;
            }

            // Configure SSH on VM
            ssh_client.execute(
                "chmod 600 ~/.ssh/id_ed25519 && \
                 chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true && \
                 ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null && \
                 git config --global user.email 'cloud-agent@localhost' && \
                 git config --global user.name 'Cloud Agent'"
            )?;

            utils::log_success("GitHub SSH key transferred");
        } else if let Some(token) = &self.config.github_token {
            utils::log("Transferring GitHub credentials (PAT)...");

            ssh_client.execute(&format!(
                "git config --global credential.helper store && \
                 echo 'https://oauth2:{}@github.com' > ~/.git-credentials && \
                 chmod 600 ~/.git-credentials && \
                 git config --global user.email 'cloud-agent@localhost' && \
                 git config --global user.name 'Cloud Agent'",
                token
            ))?;

            utils::log_success("GitHub PAT transferred");
        }

        // Transfer agent credentials
        self.transfer_agent_credentials(ssh_client).await?;

        Ok(())
    }

    /// Transfer AI agent credentials
    async fn transfer_agent_credentials(&self, ssh_client: &SshClient) -> Result<()> {
        utils::log("");
        utils::log("Transferring AI agent credentials...");

        // Transfer all agent credentials (not just the selected one)
        // This allows switching agents on the VM without re-deploying

        // Augment credentials
        if let Some(home) = dirs::home_dir() {
            let augment_creds = home.join(".augment/session.json");
            if augment_creds.exists() {
                utils::log("  Transferring Augment credentials...");
                let temp_file = tempfile::NamedTempFile::new()?;
                fs::copy(&augment_creds, temp_file.path())?;

                ssh_client.copy_to_vm(temp_file.path(), "~/augment-session-temp.json")?;
                ssh_client.execute(
                    "mkdir -p ~/.augment && \
                     mv ~/augment-session-temp.json ~/.augment/session.json && \
                     chmod 600 ~/.augment/session.json"
                )?;
                utils::log("  ✅ Augment credentials transferred");
            }

            // Claude Code credentials
            let claude_creds = home.join(".claude.json");
            if claude_creds.exists() {
                utils::log("  Transferring Claude Code credentials...");
                let temp_file = tempfile::NamedTempFile::new()?;
                fs::copy(&claude_creds, temp_file.path())?;

                ssh_client.copy_to_vm(temp_file.path(), "~/.claude.json")?;
                ssh_client.execute("chmod 600 ~/.claude.json && mkdir -p ~/.claude")?;
                utils::log("  ✅ Claude Code credentials transferred");
            }

            // Codex credentials
            let codex_creds = home.join(".codex/config.toml");
            if codex_creds.exists() {
                utils::log("  Transferring Codex credentials...");
                let temp_file = tempfile::NamedTempFile::new()?;
                fs::copy(&codex_creds, temp_file.path())?;

                ssh_client.copy_to_vm(temp_file.path(), "~/codex-config-temp.toml")?;
                ssh_client.execute(
                    "mkdir -p ~/.codex && \
                     mv ~/codex-config-temp.toml ~/.codex/config.toml && \
                     chmod 600 ~/.codex/config.toml"
                )?;
                utils::log("  ✅ Codex credentials transferred");
            }
        }

        Ok(())
    }

    /// Clone repositories to the VM
    async fn clone_repos(&self, ssh_client: &SshClient, repos: &[String]) -> Result<()> {
        utils::log("");
        utils::log("Cloning repositories to VM...");

        // Ensure /workspace is writable
        ssh_client.execute("sudo chmod 777 /workspace 2>/dev/null || true").ok();

        for repo in repos {
            let repo_name = utils::extract_repo_name(repo)?;
            utils::log(&format!("  Cloning {}...", repo_name));

            let clone_cmd = format!(
                "cd /workspace && \
                 if [ -d '{}' ]; then \
                     echo '  ⚠️  {} already exists, pulling latest...' && \
                     cd '{}' && git pull; \
                 else \
                     git clone '{}' '{}' && \
                     echo '  ✅ Cloned {}'; \
                 fi",
                repo_name, repo_name, repo_name, repo, repo_name, repo_name
            );

            ssh_client.execute(&clone_cmd)?;
        }

        utils::log_success("All repositories cloned");
        Ok(())
    }

    /// Print success message with instructions
    async fn print_success_message(&self, ssh_client: &SshClient) -> Result<()> {
        utils::log("");
        utils::log("Workspace contents:");
        if let Ok(output) = ssh_client.execute("ls -la /workspace/") {
            println!("{}", output);
        }

        let vm_ip = self.get_vm_ip().await?;

        utils::log("");
        utils::print_header("🐕 CLOUD AGENT READY!");
        utils::log("");
        utils::log("Connect to VM (with tmux):");
        utils::log("  ca ssh");
        utils::log("");
        utils::log("Or manually SSH:");
        utils::log(&format!("  ssh -i ~/.ssh/cloud-auggie {}@{}", self.config.ssh_username, vm_ip));
        utils::log("");
        utils::log("Start working:");
        utils::log("  cd /workspace/<repo-name>");
        utils::log(&format!("  {}", self.config.agent));
        utils::log("");
        utils::log("Agent can commit and push:");
        utils::log("  git checkout -b feature/my-changes");
        utils::log("  git add . && git commit -m 'Changes from cloud-agent'");
        utils::log("  git push -u origin feature/my-changes");
        utils::log("");
        utils::log("VM management:");
        utils::log("  ca list       # List VMs");
        utils::log("  ca stop       # Stop VM");
        utils::log("  ca start      # Start VM");
        utils::log("  ca terminate  # Delete VM");
        utils::log("");
        utils::log("🐕 GOOD LUCK!");

        Ok(())
    }
}

