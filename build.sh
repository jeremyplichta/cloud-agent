#!/bin/bash
# Build script for cloud-agent Rust version
# This script helps you build and install the Rust version

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🦀 CLOUD AGENT - RUST BUILD SCRIPT                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust is not installed."
    echo ""
    echo "Install Rust from: https://rustup.rs/"
    echo "Or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo ""
    exit 1
fi

echo "✓ Rust is installed"
rustc --version
cargo --version
echo ""

# Parse arguments
BUILD_TYPE="${1:-release}"

if [ "$BUILD_TYPE" = "debug" ]; then
    echo "Building debug version (faster compilation)..."
    cargo build
    BINARY_PATH="target/debug/ca"
elif [ "$BUILD_TYPE" = "release" ]; then
    echo "Building release version (optimized)..."
    cargo build --release
    BINARY_PATH="target/release/ca"
else
    echo "❌ Unknown build type: $BUILD_TYPE"
    echo "Usage: $0 [debug|release]"
    exit 1
fi

echo ""
echo "✅ Build complete!"
echo ""
echo "Binary location: $BINARY_PATH"
echo "Binary size: $(du -h "$BINARY_PATH" | cut -f1)"
echo ""

# Offer to install
read -p "Install to ~/.local/bin/ca? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p ~/.local/bin
    cp "$BINARY_PATH" ~/.local/bin/ca
    chmod +x ~/.local/bin/ca
    echo "✅ Installed to ~/.local/bin/ca"
    echo ""
    echo "Make sure ~/.local/bin is in your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Add this to your ~/.bashrc or ~/.zshrc to make it permanent."
else
    echo "Skipped installation."
    echo ""
    echo "To install manually:"
    echo "  cp $BINARY_PATH ~/.local/bin/ca"
    echo ""
    echo "Or create a symlink:"
    echo "  ln -s $(pwd)/$BINARY_PATH ~/.local/bin/ca"
fi

echo ""
echo "To verify installation:"
echo "  ca --version"
echo "  ca --help"
echo ""
echo "🦀 Happy coding!"

