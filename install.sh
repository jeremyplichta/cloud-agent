#!/bin/bash
#
# Cloud Agent CLI installer
# Downloads pre-built binary from GitHub releases
#

set -e

REPO="jeremyplichta/cloud-agent"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="ca"

# Detect OS and architecture
detect_platform() {
    local os arch

    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="macos" ;;
        *)       echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)  arch="x86_64" ;;
        arm64|aarch64) arch="aarch64" ;;
        *)             echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac

    echo "${os}-${arch}"
}

# Get latest release tag from GitHub
get_latest_release() {
    curl -s "https://api.github.com/repos/${REPO}/releases/latest" | \
        grep '"tag_name":' | \
        sed -E 's/.*"([^"]+)".*/\1/'
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🐕 CLOUD AGENT CLI INSTALLER                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Detect platform
PLATFORM=$(detect_platform)
echo "Detected platform: $PLATFORM"

# Get latest release
echo "Fetching latest release..."
VERSION=$(get_latest_release)

if [ -z "$VERSION" ]; then
    echo "❌ Could not determine latest release."
    echo ""
    echo "No releases found. You can build from source instead:"
    echo "  cargo build --release"
    echo "  cp target/release/ca ~/.local/bin/"
    exit 1
fi

echo "Latest version: $VERSION"
echo ""

# Construct download URL
ASSET_NAME="ca-${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"

echo "Downloading $ASSET_NAME..."

# Create install directory if needed
mkdir -p "$INSTALL_DIR"

# Download and extract
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if ! curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/$ASSET_NAME"; then
    echo "❌ Failed to download $DOWNLOAD_URL"
    echo ""
    echo "The release may not have binaries for your platform yet."
    echo "You can build from source instead:"
    echo "  cargo build --release"
    echo "  cp target/release/ca ~/.local/bin/"
    exit 1
fi

tar -xzf "$TEMP_DIR/$ASSET_NAME" -C "$TEMP_DIR"
mv "$TEMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo ""
echo "✅ Installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"
echo ""

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "⚠️  $INSTALL_DIR is not in your PATH"
    echo ""
    echo "Add it to your shell config:"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
    echo ""
    echo "Then restart your terminal or run:"
    echo "  source ~/.zshrc"
    echo ""
else
    echo "Run 'ca --help' to get started!"
fi

echo ""
echo "Usage:"
echo "  ca --help                         # Show help"
echo "  ca git@github.com:org/repo.git    # Deploy a repo"
echo "  ca list                           # List VMs"
echo "  ca ssh                            # SSH to VM"
echo ""
echo "🐕 Woof!"

