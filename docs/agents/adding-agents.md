# Adding New Agents

This guide explains how to add support for a new AI coding agent to Cloud Agent.

## Overview

Each agent is implemented as a Rust struct that implements the `Agent` trait.

## Agent Trait

```rust
pub trait Agent {
    /// Display name (e.g., "Claude Code")
    fn display_name(&self) -> &str;

    /// CLI command (e.g., "claude")
    fn command(&self) -> &str;

    /// Install command for the VM
    fn install_command(&self) -> &str;

    /// Check if CLI is installed locally
    fn check_local(&self) -> bool;

    /// Check if user is logged in
    fn check_logged_in(&self) -> bool;

    /// Login instructions
    fn login_instructions(&self) -> String;

    /// Path to credentials (local)
    fn credentials_path(&self) -> Option<PathBuf>;

    /// Path to credentials (on VM)
    fn remote_credentials_path(&self) -> &str;
}
```

## Implementation Steps

### 1. Create the Agent File

Create `src/agents/newagent.rs`:

```rust
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
        "npm install -g newagent-cli"
    }

    fn check_local(&self) -> bool {
        utils::command_exists("newagent")
    }

    fn check_logged_in(&self) -> bool {
        if let Some(home) = dirs::home_dir() {
            home.join(".newagent/credentials.json").exists()
        } else {
            false
        }
    }

    fn login_instructions(&self) -> String {
        "Run 'newagent login' to authenticate".to_string()
    }

    fn credentials_path(&self) -> Option<PathBuf> {
        dirs::home_dir().map(|h| h.join(".newagent"))
    }

    fn remote_credentials_path(&self) -> &str {
        "~/.newagent"
    }
}
```

### 2. Register the Agent

In `src/agents/mod.rs`, add:

```rust
mod newagent;
pub use newagent::NewAgent;

// In AgentManager::new():
"newagent" => Box::new(NewAgent),
```

### 3. Update CLI

In `src/cli.rs`, add the agent to the help text and validation.

### 4. Create Hook Script (Optional)

If the agent needs special VM setup, create `hooks/newagent.sh`:

```bash
#!/bin/bash
# Custom setup for New Agent

# Install dependencies
npm install -g newagent-cli

# Configure agent
newagent config set workspace /workspace
```

### 5. Add Documentation

Create `docs/agents/newagent.md` with:

- Prerequisites
- Installation steps
- Usage examples
- Troubleshooting

### 6. Update mkdocs.yml

Add the new page to the navigation.

## Testing

```bash
# Build
cargo build

# Test agent detection
./target/debug/ca --agent newagent --help

# Test deployment (dry run)
./target/debug/ca --agent newagent git@github.com:test/repo.git
```

## Pull Request Checklist

- [ ] Agent struct implements all trait methods
- [ ] Agent registered in `mod.rs`
- [ ] CLI updated with new agent option
- [ ] Hook script created (if needed)
- [ ] Documentation added
- [ ] Tests pass

