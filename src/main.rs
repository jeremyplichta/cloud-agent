//! Cloud Agent - Deploy repos to Cloud Agent VMs for AI coding agents
//!
//! This tool helps you create and manage Google Cloud VMs configured for
//! running AI coding agents like Auggie, Claude Code, and Codex.

mod cli;
mod config;
mod error;
mod gcp;
mod ssh;
mod git;
mod agents;
mod utils;

use anyhow::Result;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "cloud_agent=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Parse CLI arguments
    let args = cli::Args::parse();

    // Execute the command
    cli::execute(args).await?;

    Ok(())
}

