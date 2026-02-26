# Cloud Agent (Rust Implementation)

A Rust rewrite of the Cloud Agent deployment tool. This tool helps you create and manage Google Cloud VMs configured for running AI coding agents like Auggie, Claude Code, and Codex.

## Why Rust?

The original bash implementation was approaching 1000 lines and becoming difficult to maintain. This Rust version provides:

- **Better Performance**: Faster execution and more responsive
- **Type Safety**: Catch errors at compile time instead of runtime
- **Better Error Handling**: Clear, actionable error messages
- **Easier Testing**: Comprehensive test coverage
- **Better Maintainability**: Clear module structure and documentation
- **Cross-platform**: Works on Linux, macOS, and Windows

## Features

- 🚀 **Fast VM Deployment**: Create GCP VMs optimized for AI coding agents
- 🔐 **Secure by Default**: SSH key-based authentication, firewall rules
- 🤖 **Multi-Agent Support**: Works with Auggie, Claude Code, and Codex
- 📦 **Credential Management**: Automatically transfers GitHub and agent credentials
- 🔄 **Repository Cloning**: Clone multiple repos to your VM
- 💻 **Easy SSH Access**: Built-in tmux session management
- 🛠️ **VM Management**: Start, stop, list, and terminate VMs

## Installation

### Prerequisites

- Rust 1.70 or later
- Google Cloud SDK (`gcloud`)
- Terraform
- SSH client

### Build from Source

```bash
# Clone the repository
git clone git@github.com:jeremyplichta/cloud-agent.git
cd cloud-agent

# Build the release binary
cargo build --release

# Install to your PATH
cargo install --path .

# Or create a symlink
ln -s $(pwd)/target/release/ca ~/.local/bin/ca
```

## Quick Start

### 1. Configure GCP

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -C "cloud-agent"
# Add ~/.ssh/cloud-agent.pub to GitHub: Settings > SSH Keys
```

### 3. Deploy a Repository

```bash
# Deploy current repo (auto-detects origin remote)
ca

# Deploy specific repo
SSH_KEY=~/.ssh/cloud-agent ca git@github.com:org/repo.git

# Deploy with specific agent
ca --agent claude git@github.com:org/repo.git

# Deploy multiple repos
ca git@github.com:org/repo1.git git@github.com:org/repo2.git
```

### 4. SSH and Start Working

```bash
# Easy way (auto-attaches to tmux):
ca ssh

# On the VM:
cd /workspace/yourrepo
auggie  # or claude, or codex
```

## Usage

### Basic Commands

```bash
# List all cloud-agent VMs
ca list

# Start a stopped VM
ca start

# Stop a running VM
ca stop

# Terminate (delete) a VM
ca terminate

# SSH into the VM
ca ssh

# Copy files to/from VM
ca scp ./local-file.txt vm:/workspace/
ca scp vm:/workspace/file.txt ./

# Re-apply terraform (update firewall rules, etc.)
ca tf
```

### Advanced Options

```bash
# Deploy with GCP permissions
ca --permissions compute,gke,storage git@github.com:org/repo.git

# Whitelist additional IP for SSH
ca --ip 192.168.1.100 git@github.com:org/repo.git

# Use specific machine type
ca --machine-type n2-standard-8 git@github.com:org/repo.git

# Set company domain (for username derivation)
COMPANY=redis.com ca git@github.com:org/repo.git
```

## Project Structure

```
src/
├── main.rs           # Entry point
├── cli.rs            # Command-line interface
├── config.rs         # Configuration management
├── error.rs          # Error types
├── gcp.rs            # GCP/Terraform operations
├── ssh.rs            # SSH client
├── git.rs            # Git operations
├── utils.rs          # Utility functions
└── agents/           # Agent implementations
    ├── mod.rs        # Agent trait and manager
    ├── auggie.rs     # Auggie agent
    ├── claude.rs     # Claude Code agent
    └── codex.rs      # Codex agent
```

## For Rust Beginners

This codebase is designed to be beginner-friendly:

- **Clear Module Structure**: Each file has a specific purpose
- **Extensive Comments**: Every module and function is documented
- **Type Safety**: The compiler helps catch mistakes
- **Error Handling**: Uses `Result<T>` and `anyhow` for clear error messages
- **Modern Patterns**: Uses async/await, traits, and other Rust idioms

### Key Concepts Used

1. **Traits**: The `Agent` trait defines a common interface for all agents
2. **Error Handling**: Custom error types with `thiserror`
3. **Async/Await**: For concurrent operations
4. **Modules**: Code is organized into logical modules
5. **Cargo**: Rust's package manager and build tool

## Development

### Running Tests

```bash
# Run all tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test test_help_command
```

### Building

```bash
# Debug build (faster compilation)
cargo build

# Release build (optimized)
cargo build --release

# Check without building
cargo check
```

### Code Quality

```bash
# Format code
cargo fmt

# Lint code
cargo clippy

# Check for security vulnerabilities
cargo audit
```

## License

MIT

## Contributing

Contributions welcome! Please ensure:

1. Code is formatted with `cargo fmt`
2. All tests pass with `cargo test`
3. No clippy warnings with `cargo clippy`
4. Documentation is updated

