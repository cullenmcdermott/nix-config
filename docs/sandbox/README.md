# sandbox

Per-project Lima VM wrapper for AI coding agents. v1 supports Claude Code on
macOS / Apple Silicon.

## Quick start

```bash
cd <project>
sandbox claude -- -p "what is two plus two? answer in one word"
```

The first invocation runs the wizard, provisions a fresh Ubuntu VM with Nix,
Flox, and Claude Code, and starts Mutagen sync sessions plus the host bridge.
Subsequent invocations attach in well under a second.

## Subcommands

| Command | Purpose |
|---|---|
| `sandbox claude [-- args]` | Run Claude Code in the VM |
| `sandbox shell` | Bash inside the VM (escape hatch) |
| `sandbox status` | State + config + sync session health |
| `sandbox start \| stop` | Explicit lifecycle |
| `sandbox destroy [--force] [--recover]` | Delete the VM |
| `sandbox config [edit]` | Resolved config / open per-VM TOML in $EDITOR |
| `sandbox mount add \| rm <path>` | Add/remove an extra host-directory mount |
| `sandbox vm list \| switch <id>` | Multi-VM commands |

`sandbox --vm=<id> <subcommand>` operates on the named VM regardless of cwd.

## Files

- `~/.config/sandbox/config.toml` — global defaults
- `~/.config/sandbox/vms/<id>/config.toml` — per-VM overrides
- `~/.local/share/sandbox/vms/<id>/state.json` — persisted state
- `~/.local/share/sandbox/nix-warm/` — shared warm `/nix` template

## Known limitations

- **Hooks that depend on host-only tools.** `~/.claude/hooks/*` runs inside
  the VM where `op`, `gh`, etc. may not exist. Specific cases can be absorbed
  by the bridge over time.
- **Concurrent host + VM Claude on the same project.** Mutagen surfaces
  transcript conflicts. Rare in practice.
- **Network egress.** Default-open in v1; a future `network = "restricted"`
  option will re-enable pomp's RFC1918 / SSH lockdown.
- **Agents beyond Claude Code.** The wizard reserves the slot but the
  install/auth model for codex/omp is not implemented.
- **Linux host port.** Only macOS / Apple Silicon in v1. A second backend
  (likely Firecracker or libkrun) would be the right vehicle.

See `docs/superpowers/specs/2026-05-09-sandbox-design.md` for the full
design.
