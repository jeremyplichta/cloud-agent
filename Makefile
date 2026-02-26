# Makefile for cloud-agent Rust project
# Provides convenient shortcuts for common development tasks

.PHONY: help build release test clean install fmt clippy check all

# Default target
help:
	@echo "Cloud Agent - Rust Development Commands"
	@echo ""
	@echo "Available targets:"
	@echo "  make build      - Build debug version"
	@echo "  make release    - Build optimized release version"
	@echo "  make test       - Run all tests"
	@echo "  make install    - Install to ~/.cargo/bin"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make fmt        - Format code"
	@echo "  make clippy     - Run linter"
	@echo "  make check      - Quick compile check"
	@echo "  make all        - Format, clippy, test, and build"

# Build debug version (fast compilation)
build:
	cargo build

# Build release version (optimized)
release:
	cargo build --release
	@echo ""
	@echo "✅ Release binary built: target/release/ca"
	@echo ""
	@echo "To install:"
	@echo "  make install"
	@echo "  OR: ln -s $$(pwd)/target/release/ca ~/.local/bin/ca"

# Run all tests
test:
	cargo test

# Run tests with output
test-verbose:
	cargo test -- --nocapture

# Install to cargo bin directory
install:
	cargo install --path .
	@echo ""
	@echo "✅ Installed to ~/.cargo/bin/ca"
	@echo "Make sure ~/.cargo/bin is in your PATH"

# Clean build artifacts
clean:
	cargo clean

# Format code
fmt:
	cargo fmt

# Run clippy linter
clippy:
	cargo clippy -- -D warnings

# Quick compile check (no binary)
check:
	cargo check

# Run all quality checks
all: fmt clippy test release
	@echo ""
	@echo "✅ All checks passed!"

# Development workflow
dev: fmt check test
	@echo ""
	@echo "✅ Development checks passed!"

# Watch for changes and rebuild
watch:
	cargo watch -x check -x test

# Generate documentation
doc:
	cargo doc --no-deps --open

# Check for security vulnerabilities
audit:
	cargo audit

# Update dependencies
update:
	cargo update

# Show dependency tree
tree:
	cargo tree

