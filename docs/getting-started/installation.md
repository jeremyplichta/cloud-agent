# Installation

## Quick Install (Recommended)

Download and install the pre-built binary with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/jeremyplichta/cloud-agent/main/install.sh | bash
```

This automatically:

- Detects your platform (Linux/macOS, x86_64/ARM64)
- Downloads the latest release
- Installs to `~/.local/bin/ca`

## Alternative Installation Methods

### Build from Source

Requires [Rust](https://rustup.rs/) (latest stable):

```bash
# Clone the repository
git clone git@github.com:jeremyplichta/cloud-agent.git
cd cloud-agent

# Build release binary
cargo build --release

# Install to PATH
cp target/release/ca ~/.local/bin/
```

### Download Binary Manually

Download from [GitHub Releases](https://github.com/jeremyplichta/cloud-agent/releases):

| Platform | Download |
|----------|----------|
| Linux (Intel/AMD) | `ca-linux-x86_64.tar.gz` |
| Linux (Static) | `ca-linux-x86_64-musl.tar.gz` |
| macOS (Intel) | `ca-macos-x86_64.tar.gz` |
| macOS (Apple Silicon) | `ca-macos-aarch64.tar.gz` |

```bash
# Example: macOS Apple Silicon
curl -LO https://github.com/jeremyplichta/cloud-agent/releases/latest/download/ca-macos-aarch64.tar.gz
tar -xzf ca-macos-aarch64.tar.gz
mv ca ~/.local/bin/
chmod +x ~/.local/bin/ca
```

## Verify Installation

```bash
ca --version
ca --help
```

## Add to PATH

If `~/.local/bin` is not in your PATH, add it:

=== "Zsh"

    ```bash
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
    ```

=== "Bash"

    ```bash
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    ```

## Uninstall

```bash
rm ~/.local/bin/ca
```

Or use the uninstall script:

```bash
curl -fsSL https://raw.githubusercontent.com/jeremyplichta/cloud-agent/main/uninstall.sh | bash
```

## Next Steps

- [Set up prerequisites](prerequisites.md)
- [Quick start guide](quick-start.md)

