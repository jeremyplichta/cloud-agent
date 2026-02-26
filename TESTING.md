# Testing Guide

This guide explains how to test the cloud-agent Rust implementation.

## Running Tests

### All Tests

```bash
# Run all tests
cargo test

# Run with output
cargo test -- --nocapture

# Run with verbose output
cargo test -- --nocapture --test-threads=1
```

### Specific Tests

```bash
# Run a specific test
cargo test test_help_command

# Run tests in a specific file
cargo test --test integration_test

# Run tests matching a pattern
cargo test ip
```

### Test Coverage

```bash
# Install tarpaulin (coverage tool)
cargo install cargo-tarpaulin

# Generate coverage report
cargo tarpaulin --out Html
```

## Test Structure

### Unit Tests

Unit tests are located in the same file as the code they test:

```rust
// In src/utils.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_valid_ipv4() {
        assert!(is_valid_ipv4("192.168.1.1"));
        assert!(!is_valid_ipv4("256.1.1.1"));
    }
}
```

### Integration Tests

Integration tests are in the `tests/` directory:

```rust
// In tests/integration_test.rs
use assert_cmd::Command;

#[test]
fn test_help_command() {
    let mut cmd = Command::cargo_bin("ca").unwrap();
    cmd.arg("--help");
    cmd.assert().success();
}
```

## Manual Testing

### Prerequisites

Before manual testing, ensure you have:

1. ✅ Rust installed
2. ✅ GCP project configured
3. ✅ SSH key for GitHub
4. ✅ Terraform installed

### Test Checklist

#### Build and Installation

- [ ] `cargo build` succeeds
- [ ] `cargo build --release` succeeds
- [ ] `./build.sh` works
- [ ] Binary runs: `./target/release/ca --version`

#### Basic Commands

- [ ] `ca --help` shows help
- [ ] `ca --version` shows version
- [ ] `ca list` lists VMs (or shows empty)

#### VM Creation

- [ ] `ca git@github.com:org/repo.git` creates VM
- [ ] Terraform files are generated
- [ ] VM appears in `ca list`
- [ ] Firewall rules are created

#### SSH and Credentials

- [ ] `ca ssh` connects to VM
- [ ] SSH keys are transferred
- [ ] Agent credentials are transferred
- [ ] Git is configured on VM

#### Repository Management

- [ ] Repository is cloned to `/workspace/`
- [ ] Multiple repos can be deployed
- [ ] Existing repos are updated (git pull)

#### File Transfer

- [ ] `ca scp ./file.txt vm:/workspace/` uploads
- [ ] `ca scp vm:/workspace/file.txt ./` downloads
- [ ] Directory transfer works

#### VM Management

- [ ] `ca stop` stops VM
- [ ] `ca start` starts VM
- [ ] `ca terminate` deletes VM
- [ ] `ca tf` re-applies terraform

#### Error Handling

- [ ] Invalid agent shows clear error
- [ ] Missing SSH key shows clear error
- [ ] No GCP project shows clear error
- [ ] Invalid repo URL shows clear error

#### Different Agents

- [ ] `--agent auggie` works
- [ ] `--agent claude` works
- [ ] `--agent codex` works

#### Advanced Features

- [ ] `--permissions compute,gke` grants permissions
- [ ] `--ip 1.2.3.4` whitelists IP
- [ ] `--machine-type n2-standard-8` uses custom type
- [ ] `COMPANY=redis.com` affects username

## Automated Testing

### GitHub Actions (Future)

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      - run: cargo test
      - run: cargo clippy
      - run: cargo fmt -- --check
```

## Performance Testing

### Benchmarks

```bash
# Install criterion
cargo install cargo-criterion

# Run benchmarks (if we add them)
cargo criterion
```

### Manual Performance Testing

Compare with bash version:

```bash
# Bash version
time ./deploy.sh --list

# Rust version
time ca list
```

## Debugging Tests

### Enable Logging

```bash
# Run tests with debug logging
RUST_LOG=debug cargo test -- --nocapture
```

### Run Single Test

```bash
# Run one test for debugging
cargo test test_name -- --nocapture --test-threads=1
```

### Use println! in Tests

```rust
#[test]
fn test_something() {
    println!("Debug info: {:?}", value);
    assert_eq!(value, expected);
}
```

## Common Issues

### Tests Fail Due to Missing GCP Config

Some tests require GCP to be configured. These are expected to fail in CI:

```rust
#[test]
#[ignore]  // Ignore in CI
fn test_gcp_operation() {
    // Test that requires GCP
}
```

Run ignored tests:
```bash
cargo test -- --ignored
```

### Tests Fail Due to Network

Tests that require network access may fail:

```rust
#[test]
#[cfg(not(ci))]  // Skip in CI
fn test_network_operation() {
    // Test that requires network
}
```

## Best Practices

1. **Write tests first** - TDD helps design better APIs
2. **Test edge cases** - Empty strings, None values, errors
3. **Use descriptive names** - `test_extract_repo_name_from_ssh_url`
4. **Keep tests simple** - One assertion per test when possible
5. **Mock external dependencies** - Don't rely on network/GCP in unit tests
6. **Document test intent** - Add comments explaining what's being tested

## Example Test

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_repo_name_from_ssh_url() {
        // Given an SSH URL
        let url = "git@github.com:org/repo.git";
        
        // When we extract the repo name
        let result = extract_repo_name(url).unwrap();
        
        // Then we get just the repo name
        assert_eq!(result, "repo");
    }

    #[test]
    fn test_extract_repo_name_from_https_url() {
        let url = "https://github.com/org/repo.git";
        let result = extract_repo_name(url).unwrap();
        assert_eq!(result, "repo");
    }

    #[test]
    fn test_extract_repo_name_invalid_url() {
        let url = "not-a-url";
        let result = extract_repo_name(url);
        assert!(result.is_err());
    }
}
```

## Continuous Improvement

As you add features:

1. ✅ Write tests for new code
2. ✅ Update existing tests if behavior changes
3. ✅ Add integration tests for new commands
4. ✅ Document test requirements
5. ✅ Keep test coverage high

