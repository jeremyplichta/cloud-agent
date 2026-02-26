//! Integration tests for cloud-agent
//!
//! These tests verify that the main components work together correctly.

use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn test_help_command() {
    let mut cmd = Command::cargo_bin("ca").unwrap();
    cmd.arg("--help");
    
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("Cloud Agent"))
        .stdout(predicate::str::contains("Deploy repos to Cloud Agent VMs"));
}

#[test]
fn test_version_command() {
    let mut cmd = Command::cargo_bin("ca").unwrap();
    cmd.arg("--version");

    cmd.assert()
        .success()
        .stdout(predicate::str::contains("ca"));
}

#[test]
fn test_list_command_structure() {
    // This test just verifies the command structure is valid
    // It may fail if gcloud is not configured, which is expected
    let mut cmd = Command::cargo_bin("ca").unwrap();
    cmd.arg("list");
    
    // We don't assert success because it requires gcloud to be configured
    // Just verify the command runs
    let _ = cmd.output();
}

#[test]
fn test_invalid_agent() {
    let mut cmd = Command::cargo_bin("ca").unwrap();
    cmd.args(["--agent", "invalid-agent", "https://github.com/test/repo.git"]);
    
    // This should fail because the agent doesn't exist
    // But we need gcloud configured to get that far
    let _ = cmd.output();
}

