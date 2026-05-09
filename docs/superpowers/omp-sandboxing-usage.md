# OMP Sandboxing — Usage Guide

## Quick Start

```bash
# Start omp with all sandbox extensions
omp -e vm-manager -e permission-gate -e secret-forwarder

# Start omp without VM (local execution)
omp --no-vm

# Check VM status
/vm

# Check forwarded secrets
/secrets
```

## Extensions

### VM Manager

Provides isolated execution in a Lima VZ virtual machine. All file operations and bash commands run inside the VM via SSH.

- VM starts automatically on session start
- VM is ephemeral — deleted on session end
- `/nix` store persists across sessions for warm cache
- Project directory synced via Mutagen
- Flox environment activated automatically

Configuration: `~/.config/omp/agent/extensions/vm-manager.json` or `.omp/vm-manager.json`

### Permission Gate

Classifies bash commands as auto-approved or requiring user confirmation.

- Read-only commands (`git status`, `kubectl get`, `rg`, etc.) auto-approve
- Mutative commands (`kubectl apply`, `rm`, `sudo`, etc.) require confirmation
- "Always allow" options write to project config for persistence
- Unknown commands default to requiring confirmation

Configuration: `~/.config/omp/agent/extensions/permission-gate.json` or `.omp/permission-gate.json`

### Secret Forwarder

Explicitly allowlists which secrets and ports can reach the VM.

- No env vars, sockets, files, or ports forwarded by default
- Global config only (no project-level overrides — security)
- Detects auth URLs in output and offers to open them in the browser

Configuration: `~/.config/omp/agent/extensions/secret-forwarder.json`

## Architecture

```
macOS Host (omp TUI) ←→ Lima VM (VZ)
                        ├── Flox environment
                        ├── Docker (inside VM)
                        ├── /nix persistent volume
                        └── ~/project (Mutagen sync)
```

## Adding Tools to the VM

Use Flox inside the VM:

```bash
# The agent can install tools
flox install kubectl
flox install helm
flox install kind
```

Changes to `.flox/env/manifest.toml` sync back to the laptop via Mutagen.

## Adding Secrets

Edit `~/.config/omp/agent/extensions/secret-forwarder.json`:

```json
{
  "envVars": ["KUBECONFIG", "AWS_PROFILE"],
  "sockets": ["~/.ssh/agent.sock"],
  "files": ["~/.kube/config"],
  "forwardPorts": {
    "auto": true,
    "static": [{ "from": 8080, "label": "OIDC callback" }],
    "ranges": [{ "start": 3000, "end": 3100, "label": "dev servers" }]
  }
}
```
