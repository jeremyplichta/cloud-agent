# Contributing to Cloud Agent

Thank you for your interest in contributing! This guide will help you get started.

## Development Setup

### Prerequisites

- Rust 1.70 or later
- Google Cloud SDK
- Terraform
- Git

### Getting Started

```bash
# Clone the repository
git clone git@github.com:jeremyplichta/cloud-agent.git
cd cloud-agent

# Build the project
cargo build

# Run tests
cargo test

# Format code
cargo fmt

# Run linter
cargo clippy
```

## Project Structure

```
src/
├── main.rs           # Entry point
├── cli.rs            # Command-line interface (clap)
├── config.rs         # Configuration management
├── error.rs          # Custom error types
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

## Code Style

We follow standard Rust conventions:

- Use `cargo fmt` to format code
- Use `cargo clippy` to catch common mistakes
- Write documentation comments (`///`) for public items
- Keep functions small and focused
- Use descriptive variable names

### Example

```rust
/// Detect public IPv4 address
///
/// Tries multiple services for reliability. Returns the IP
/// address in CIDR notation (e.g., "1.2.3.4/32").
pub async fn detect_public_ipv4() -> Result<String> {
    // Implementation...
}
```

## Testing

### Running Tests

```bash
# Run all tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test test_name
```

### Writing Tests

Add tests in the same file as the code:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_repo_name() {
        assert_eq!(
            extract_repo_name("git@github.com:org/repo.git").unwrap(),
            "repo"
        );
    }
}
```

## Adding a New Agent

To add support for a new AI coding agent:

1. Create a new file in `src/agents/` (e.g., `newagent.rs`)
2. Implement the `Agent` trait
3. Add the agent to `src/agents/mod.rs`
4. Update the agent matching in `AgentManager::new()`

Example:

```rust
// src/agents/newagent.rs
use std::path::PathBuf;
use crate::agents::Agent;
use crate::utils;

pub struct NewAgent;

impl Agent for NewAgent {
    fn display_name(&self) -> &str {
        "New Agent"
    }

    fn command(&self) -> &str {
        "newagent"
    }

    fn install_command(&self) -> &str {
        "npm install -g newagent"
    }

    fn check_local(&self) -> bool {
        utils::command_exists("newagent")
    }

    fn check_logged_in(&self) -> bool {
        if let Some(home) = dirs::home_dir() {
            home.join(".newagent/config.json").exists()
        } else {
            false
        }
    }

    fn login_instructions(&self) -> String {
        "Run 'newagent login' to authenticate".to_string()
    }

    fn credentials_path(&self) -> Option<PathBuf> {
        dirs::home_dir().map(|h| h.join(".newagent/config.json"))
    }

    fn remote_credentials_path(&self) -> &str {
        "~/.newagent/config.json"
    }
}
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and linters:
   ```bash
   cargo fmt
   cargo clippy
   cargo test
   ```
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### PR Checklist

- [ ] Code is formatted with `cargo fmt`
- [ ] No clippy warnings (`cargo clippy`)
- [ ] All tests pass (`cargo test`)
- [ ] New code has tests
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated (if applicable)

## Code Review

All submissions require review. We use GitHub pull requests for this purpose.

## Questions?

Feel free to open an issue for:

- Bug reports
- Feature requests
- Questions about the code
- Documentation improvements

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

