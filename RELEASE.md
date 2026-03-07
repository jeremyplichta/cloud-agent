# Release Process

This document describes the automated release process for cloud-agent using release-please and GitHub Actions.

## Overview

We use [release-please](https://github.com/googleapis/release-please) for automated semantic versioning and releases. This provides:

- **Automated version bumping** based on conventional commits
- **Automatic CHANGELOG generation** from commit messages
- **GitHub releases** with pre-built binaries
- **crates.io publishing** (optional)

## Conventional Commits

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Commit Types

- `feat:` - New feature (bumps minor version)
- `fix:` - Bug fix (bumps patch version)
- `perf:` - Performance improvement (bumps patch version)
- `docs:` - Documentation changes (no version bump)
- `style:` - Code style changes (no version bump)
- `refactor:` - Code refactoring (no version bump)
- `test:` - Test changes (no version bump)
- `build:` - Build system changes (no version bump)
- `ci:` - CI configuration changes (no version bump)
- `chore:` - Other changes (no version bump)

### Breaking Changes

Add `BREAKING CHANGE:` in the commit body or `!` after the type to bump major version:

```
feat!: remove deprecated API

BREAKING CHANGE: The old API has been removed. Use the new API instead.
```

### Examples

```bash
# Feature (bumps 0.1.0 -> 0.2.0)
git commit -m "feat: add support for AWS deployments"

# Bug fix (bumps 0.1.0 -> 0.1.1)
git commit -m "fix: correct SSH key detection on macOS"

# Breaking change (bumps 0.1.0 -> 1.0.0)
git commit -m "feat!: redesign CLI interface

BREAKING CHANGE: Command structure has changed. See migration guide."

# Documentation (no version bump)
git commit -m "docs: update installation instructions"
```

## Release Workflow

### 1. Development

Make changes and commit using conventional commits:

```bash
git checkout -b feature/my-feature
# Make changes
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

### 2. Pull Request

Create a PR to `main`. The CI workflows will run:

- ✅ Tests on multiple platforms
- ✅ Code formatting check
- ✅ Clippy lints
- ✅ Security audit
- ✅ Documentation check

### 3. Merge to Main

When the PR is merged to `main`, release-please will:

1. Analyze commits since last release
2. Determine next version number
3. Create/update a "release PR"
4. Update CHANGELOG.md
5. Update version in Cargo.toml

### 4. Release PR

A release PR will be automatically created with:

- Title: `chore: release X.Y.Z`
- Updated CHANGELOG.md
- Updated Cargo.toml version
- Summary of changes

**Review the release PR** to ensure:
- Version number is correct
- CHANGELOG is accurate
- All changes are included

### 5. Trigger Release

**Merge the release PR** to trigger the release workflow:

1. **Build binaries** for multiple platforms:
   - Linux (x86_64, musl, aarch64)
   - macOS (Intel, Apple Silicon)

2. **Create GitHub release** with:
   - Release notes from CHANGELOG
   - Pre-built binaries
   - SHA256 checksums

3. **Publish to crates.io** (if configured)

### 6. Post-Release

After release:
- GitHub release is created with binaries
- Git tag is created (e.g., `v0.2.0`)
- CHANGELOG is updated
- Version is bumped in Cargo.toml

## Manual Release (Emergency)

If you need to create a release manually:

```bash
# 1. Update version in Cargo.toml
vim Cargo.toml

# 2. Update CHANGELOG.md
vim CHANGELOG.md

# 3. Commit changes
git add Cargo.toml CHANGELOG.md
git commit -m "chore: release X.Y.Z"

# 4. Create tag
git tag -a vX.Y.Z -m "Release X.Y.Z"

# 5. Push
git push origin main --tags
```

The build workflow will trigger on the tag and create the release.

## Configuration Files

### `.release-please-manifest.json`

Tracks the current version:

```json
{
  ".": "0.1.0"
}
```

### `release-please-config.json`

Configures release-please behavior:

- Release type: `rust`
- Package name: `cloud-agent`
- Changelog sections
- Version bump rules
- Extra files to update

## GitHub Actions Workflows

### `ci.yml`

Runs on every push and PR:
- Tests on Ubuntu and macOS
- Rust stable and beta
- Code formatting
- Clippy lints
- Security audit
- Code coverage

### `release-please.yml`

Runs on push to `main`:
- Creates/updates release PR
- Builds binaries when release PR is merged
- Creates GitHub release
- Publishes to crates.io

### `build.yml`

Runs on tags and manual trigger:
- Builds binaries for all platforms
- Creates release with artifacts

### `security.yml`

Runs daily and on dependency changes:
- Security audit with cargo-audit
- Dependency review
- License compliance

### `quality.yml`

Runs on push and PR:
- Clippy lints
- Code formatting
- Documentation check
- Unused dependencies
- MSRV check

## Secrets Required

Configure these secrets in GitHub repository settings:

- `GITHUB_TOKEN` - Automatically provided by GitHub
- `CARGO_REGISTRY_TOKEN` - For publishing to crates.io (optional)

To get a crates.io token:
1. Go to https://crates.io/settings/tokens
2. Create a new token
3. Add to GitHub secrets as `CARGO_REGISTRY_TOKEN`

## Version Strategy

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0) - Breaking changes
- **MINOR** (0.X.0) - New features (backward compatible)
- **PATCH** (0.0.X) - Bug fixes (backward compatible)

Pre-1.0.0 versions:
- Breaking changes bump minor version
- Features bump minor version
- Bug fixes bump patch version

## Troubleshooting

### Release PR not created

Check:
- Commits follow conventional commit format
- Commits are on `main` branch
- Previous release PR is merged/closed

### Build fails

Check:
- All tests pass locally
- Dependencies are up to date
- Cargo.toml is valid

### crates.io publish fails

Check:
- `CARGO_REGISTRY_TOKEN` is set
- Package name is available
- Version doesn't already exist

## Best Practices

1. **Use conventional commits** - Enables automatic versioning
2. **Write good commit messages** - They become release notes
3. **Review release PRs** - Ensure version and changelog are correct
4. **Test before merging** - CI must pass
5. **Keep dependencies updated** - Run `cargo update` regularly
6. **Document breaking changes** - Help users migrate

## Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [release-please](https://github.com/googleapis/release-please)
- [GitHub Actions](https://docs.github.com/en/actions)

