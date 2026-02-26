# GitHub Actions Workflows

This directory contains automated workflows for CI/CD, releases, and quality checks.

## Workflows

### 🧪 CI (`ci.yml`)

**Triggers**: Push to main/feature branches, Pull Requests

**Jobs**:
- **Test** - Run tests on Ubuntu and macOS with stable and beta Rust
- **Format** - Check code formatting with rustfmt
- **Clippy** - Run linter checks
- **Security** - Run cargo-audit for vulnerabilities
- **Coverage** - Generate code coverage reports
- **Build** - Build release binaries

**Status**: ![CI](https://github.com/jeremyplichta/cloud-agent/workflows/CI/badge.svg)

### 📦 Release Please (`release-please.yml`)

**Triggers**: Push to main

**Jobs**:
- **release-please** - Create/update release PR based on conventional commits
- **build-and-upload** - Build binaries for multiple platforms when release is created
- **publish-crate** - Publish to crates.io (optional)
- **create-github-release** - Create GitHub release with binaries

**How it works**:
1. Analyzes commits since last release
2. Creates a release PR with version bump and CHANGELOG
3. When release PR is merged, builds binaries and creates release

**Status**: ![Release](https://github.com/jeremyplichta/cloud-agent/workflows/Release%20Please/badge.svg)

### 🔨 Build (`build.yml`)

**Triggers**: Git tags (v*), Manual workflow dispatch

**Jobs**:
- **build** - Build optimized binaries for:
  - Linux (x86_64, musl, aarch64)
  - macOS (Intel, Apple Silicon)
- **create-release** - Create GitHub release with all binaries

**Artifacts**:
- `ca-linux-x86_64.tar.gz` - Linux binary (glibc)
- `ca-linux-x86_64-musl.tar.gz` - Linux binary (musl, static)
- `ca-linux-aarch64.tar.gz` - Linux ARM64 binary
- `ca-macos-x86_64.tar.gz` - macOS Intel binary
- `ca-macos-aarch64.tar.gz` - macOS Apple Silicon binary
- SHA256 checksums for all binaries

**Status**: ![Build](https://github.com/jeremyplichta/cloud-agent/workflows/Build%20Binaries/badge.svg)

### 🔒 Security (`security.yml`)

**Triggers**: Daily at 00:00 UTC, Push/PR with dependency changes, Manual

**Jobs**:
- **audit** - Run cargo-audit for known vulnerabilities
- **dependency-review** - Review dependency changes in PRs
- **supply-chain** - Check licenses and advisories with cargo-deny

**Status**: ![Security](https://github.com/jeremyplichta/cloud-agent/workflows/Security%20Audit/badge.svg)

### ✨ Quality (`quality.yml`)

**Triggers**: Push to main/feature branches, Pull Requests

**Jobs**:
- **clippy** - Lint code with clippy (deny warnings)
- **fmt** - Check code formatting
- **doc** - Check documentation builds without warnings
- **unused-deps** - Check for unused dependencies
- **msrv** - Verify Minimum Supported Rust Version (1.70)

**Status**: ![Quality](https://github.com/jeremyplichta/cloud-agent/workflows/Code%20Quality/badge.svg)

## Secrets Required

Configure these in repository settings → Secrets and variables → Actions:

- `GITHUB_TOKEN` - Automatically provided by GitHub ✅
- `CARGO_REGISTRY_TOKEN` - For publishing to crates.io (optional)

## Caching Strategy

All workflows use GitHub Actions cache for:
- Cargo registry (`~/.cargo/registry`)
- Cargo git index (`~/.cargo/git`)
- Build artifacts (`target/`)

This significantly speeds up builds (2-3x faster).

## Platform Support

### Tested Platforms
- ✅ Ubuntu Latest (x86_64)
- ✅ macOS Latest (x86_64, aarch64)

### Built Platforms
- ✅ Linux x86_64 (glibc)
- ✅ Linux x86_64 (musl, static)
- ✅ Linux aarch64 (ARM64)
- ✅ macOS x86_64 (Intel)
- ✅ macOS aarch64 (Apple Silicon)

## Rust Versions

- **Stable** - Primary target, always tested
- **Beta** - Tested for early warning of issues
- **MSRV** - Minimum Supported Rust Version: 1.70

## Conventional Commits

All workflows expect conventional commit messages:

- `feat:` - New feature (minor version bump)
- `fix:` - Bug fix (patch version bump)
- `docs:` - Documentation (no version bump)
- `chore:` - Maintenance (no version bump)
- `feat!:` or `BREAKING CHANGE:` - Breaking change (major version bump)

See [RELEASE.md](../../RELEASE.md) for details.

## Workflow Dependencies

```
Push to main
    ↓
CI (tests, lint, security)
    ↓
Release Please (create/update PR)
    ↓
Merge Release PR
    ↓
Build Binaries (all platforms)
    ↓
Create GitHub Release
    ↓
Publish to crates.io (optional)
```

## Manual Triggers

Some workflows can be triggered manually:

1. Go to Actions tab
2. Select workflow
3. Click "Run workflow"
4. Choose branch
5. Click "Run workflow"

**Manually triggerable workflows**:
- Build Binaries
- Security Audit

## Troubleshooting

### Workflow fails on cache

Clear cache:
1. Go to Actions → Caches
2. Delete relevant caches
3. Re-run workflow

### Release PR not created

Check:
- Commits use conventional format
- Previous release PR is closed
- Commits are on main branch

### Build fails

Check:
- Tests pass locally
- Dependencies compile
- Cargo.toml is valid

## Best Practices

1. ✅ Always use conventional commits
2. ✅ Let CI run before merging PRs
3. ✅ Review release PRs before merging
4. ✅ Keep dependencies updated
5. ✅ Fix security issues promptly
6. ✅ Monitor workflow runs

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [release-please](https://github.com/googleapis/release-please)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

