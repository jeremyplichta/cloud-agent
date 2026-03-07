# VM Management

Commands for managing your Cloud Agent VMs.

## List VMs

Show all Cloud Agent VMs in your GCP project:

```bash
ca list
```

Output:

```
NAME                    STATUS    ZONE            MACHINE TYPE    EXTERNAL IP
cloud-agent-jsmith      RUNNING   us-central1-a   e2-standard-4   35.192.0.42
cloud-agent-jsmith-2    STOPPED   us-central1-a   e2-standard-4   -
```

## Start VM

Start a stopped VM:

```bash
ca start
```

!!! tip "Cost Savings"
    Stop your VM when not in use to save on GCP costs. Your work is preserved on disk.

## Stop VM

Stop a running VM (preserves disk):

```bash
ca stop
```

The VM disk is preserved, so you can resume later with `ca start`.

## Terminate VM

Permanently delete the VM and all associated resources:

```bash
ca terminate
```

!!! warning "Destructive"
    This permanently deletes the VM and its disk. Make sure to commit and push any changes first.

## Terraform Commands

Re-apply Terraform configuration (useful for updating firewall rules):

```bash
ca tf
```

This is useful when:

- Your IP address changed
- You want to update firewall rules
- You modified `terraform.tfvars`

## Multiple VMs

Cloud Agent supports one VM per user by default. The VM name is derived from your username/email.

To manage a specific VM:

```bash
# List all VMs
ca list

# Operations use the default VM name
ca start
ca stop
ca terminate
```

## GCP Console

You can also manage VMs directly in the GCP Console:

1. Go to [Compute Engine → VM instances](https://console.cloud.google.com/compute/instances)
2. Find VMs starting with `cloud-agent-`
3. Use the console actions (Start, Stop, Delete)

## Resource Cleanup

To clean up all Cloud Agent resources:

```bash
# Delete the VM
ca terminate

# Remove local Terraform state (optional)
rm -rf .terraform terraform.tfstate*
```

