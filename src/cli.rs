//! Command-line interface for cloud-agent
//!
//! This module handles parsing command-line arguments and executing commands.
//! We use the `clap` crate which makes it easy to build CLI tools.

use clap::{Parser, Subcommand};
use anyhow::Result;

use crate::config::Config;
use crate::gcp::VmManager;
use crate::agents::AgentManager;

/// Cloud Agent - Deploy repos to Cloud Agent VMs for AI coding agents
#[derive(Parser, Debug)]
#[command(name = "ca")]
#[command(author, version, about, long_about = None)]
pub struct Args {
    /// Agent to use (auggie, claude, codex)
    #[arg(long, env = "AGENT", default_value = "auggie")]
    pub agent: String,

    /// GCP zone
    #[arg(long, env = "ZONE", default_value = "us-central1-a")]
    pub zone: String,

    /// VM machine type
    #[arg(long, env = "MACHINE_TYPE", default_value = "n2-standard-4")]
    pub machine_type: String,

    /// GKE cluster name (optional)
    #[arg(long, env = "CLUSTER_NAME")]
    pub cluster_name: Option<String>,

    /// Path to SSH private key for GitHub
    #[arg(long, env = "SSH_KEY")]
    pub ssh_key: Option<String>,

    /// GitHub personal access token
    #[arg(long, env = "GITHUB_TOKEN")]
    pub github_token: Option<String>,

    /// Skip deletion label (yes/no)
    #[arg(long, env = "SKIP_DELETION", default_value = "yes")]
    pub skip_deletion: String,

    /// Comma-separated permissions for VM service account
    #[arg(long, env = "PERMISSIONS")]
    pub permissions: Option<String>,

    /// Additional IP address to whitelist for SSH
    #[arg(long, env = "ADDITIONAL_IP")]
    pub additional_ip: Option<String>,

    /// Override the derived username/owner
    #[arg(long, env = "USERNAME")]
    pub username: Option<String>,

    /// Company domain to append to username
    #[arg(long, env = "COMPANY")]
    pub company: Option<String>,

    #[command(subcommand)]
    pub command: Option<Command>,

    /// Repository URLs to deploy (if no subcommand)
    #[arg(value_name = "REPO_URL")]
    pub repos: Vec<String>,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// List cloud-agent VMs and their status
    List,

    /// Start a stopped cloud-agent VM
    Start,

    /// Stop (but don't delete) the cloud-agent VM
    Stop,

    /// Terminate (delete) the cloud-agent VM
    Terminate,

    /// SSH into the VM and attach to tmux session
    Ssh,

    /// Copy files to/from VM using 'vm:' prefix for remote paths
    Scp {
        /// Source path (use 'vm:' prefix for remote)
        src: String,
        /// Destination path (use 'vm:' prefix for remote)
        dst: String,
    },

    /// Re-apply terraform with current variables
    Tf,

    /// Create VM (force creation even if it exists)
    CreateVm,

    /// Deploy repos to existing VM (skip VM creation)
    Deploy {
        /// Repository URLs to deploy
        repos: Vec<String>,
        /// Skip credential transfer
        #[arg(long)]
        skip_creds: bool,
    },
}

impl Args {
    /// Parse arguments from command line
    pub fn parse() -> Self {
        <Self as Parser>::parse()
    }
}

/// Execute the command based on parsed arguments
pub async fn execute(args: Args) -> Result<()> {
    // Load configuration
    let config = Config::from_args(&args)?;

    // Create managers
    let vm_manager = VmManager::new(config.clone());
    let agent_manager = AgentManager::new(config.clone())?;

    // Check agent prerequisites
    agent_manager.check_prerequisites().await?;

    // Execute command
    match args.command {
        Some(Command::List) => vm_manager.list().await?,
        Some(Command::Start) => vm_manager.start().await?,
        Some(Command::Stop) => vm_manager.stop().await?,
        Some(Command::Terminate) => vm_manager.terminate().await?,
        Some(Command::Ssh) => vm_manager.ssh().await?,
        Some(Command::Scp { src, dst }) => vm_manager.scp(&src, &dst).await?,
        Some(Command::Tf) => vm_manager.apply_terraform().await?,
        Some(Command::CreateVm) => {
            vm_manager.create_vm(true).await?;
        }
        Some(Command::Deploy { repos, skip_creds }) => {
            vm_manager.deploy_repos(&repos, skip_creds).await?;
        }
        None => {
            // Default behavior: deploy repos (create VM if needed)
            let repos = if args.repos.is_empty() {
                // Try to detect from current git directory
                crate::git::detect_current_repo()?
            } else {
                args.repos
            };

            vm_manager.full_deploy(&repos).await?;
        }
    }

    Ok(())
}

