# Development Setup

Guide for setting up a development environment for Cloud Agent.

## Prerequisites

- Rust (latest stable)
- Google Cloud SDK
- Terraform
- Git

## Getting Started

### Clone Repository

```bash
git clone git@github.com:jeremyplichta/cloud-agent.git
cd cloud-agent
```

### Build

```bash
# Debug build (faster compilation)
cargo build

# Release build (optimized)
cargo build --release
```

### Run Tests

```bash
# All tests
cargo test

# With output
cargo test -- --nocapture

# Specific test
cargo test test_help_command
```

### Code Quality

```bash
# Format code
cargo fmt

# Lint
cargo clippy

# Security audit
cargo audit
```

## Development Workflow

### 1. Create Branch

```bash
git checkout -b feature/my-feature
```

### 2. Make Changes

Edit code in `src/`.

### 3. Test

```bash
cargo test
cargo clippy
cargo fmt --check
```

### 4. Run Locally

```bash
# Run directly
cargo run -- --help

# Or build and run
cargo build
./target/debug/ca --help
```

### 5. Commit

```bash
git add .
git commit -m "feat: add my feature"
```

### 6. Push and PR

```bash
git push origin feature/my-feature
# Open PR on GitHub
```

## Project Structure

```
src/
├── main.rs           # Entry point
├── cli.rs            # CLI argument parsing (clap)
├── config.rs         # Configuration management
├── error.rs          # Custom error types
├── gcp.rs            # GCP/Terraform operations
├── ssh.rs            # SSH client wrapper
├── git.rs            # Git operations
├── utils.rs          # Utility functions
└── agents/           # Agent implementations
    ├── mod.rs        # Agent trait
    ├── auggie.rs     # Auggie agent
    ├── claude.rs     # Claude agent
    └── codex.rs      # Codex agent
```

## Key Concepts

### Error Handling

We use `anyhow` for error handling:

```rust
use anyhow::{Result, Context};

fn my_function() -> Result<()> {
    do_something().context("Failed to do something")?;
    Ok(())
}
```

### Agent Trait

All agents implement the `Agent` trait. See [Adding Agents](../agents/adding-agents.md).

### Async

We use Tokio for async operations:

```rust
#[tokio::main]
async fn main() -> Result<()> {
    // async code
}
```

## Useful Commands

```bash
# Watch for changes and rebuild
cargo watch -x build

# Generate docs
cargo doc --open

# Check without building
cargo check

# Update dependencies
cargo update
```

## IDE Setup

### VS Code

Install extensions:
- rust-analyzer
- Even Better TOML
- CodeLLDB (for debugging)

### IntelliJ/RustRover

Install Rust plugin.

## Getting Help

- Open an issue on GitHub
- Check existing issues for similar problems
- Read the Rust documentation

