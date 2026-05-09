# Spike: Mutagen vs virtiofs for project directory sync

**Date:** 2026-05-09
**Drives:** Phase 5 (mounts), Phase 6 (Mutagen sync)
**Status:** resolved

## Question

Should the project directory mount use Mutagen two-way sync or Lima's built-in
virtiofs? The spec's current design says Mutagen. Does that still hold given:
- Mutagen requires a host daemon and has sync corner cases on large trees
- virtiofs avoids sync entirely but has a macOS performance reputation

## Findings

### Mutagen availability

Mutagen is **not in Homebrew** but is available via `nixpkgs#mutagen` (v0.18.0,
verified installed via `nix build nixpkgs#mutagen`). The wrapper script or
binary path can point at the Nix-installed binary without a separate brew dep.

### Lima virtiofs support

Lima's `vz` driver (Apple Silicon) supports `--mount-type=virtiofs` backed by
QEMU's `virtiofsd`. QEMU is already in scope for Lima (it's in the PATH via the
`limactl` wrapper). Ubuntu 24.04's kernel has `CONFIG_VIRTIO_FS=y` (verified in
the spike VM). This means virtiofs is a valid technical option.

### virtiofs on macOS: the performance concern

The spec cites "virtiofs perf cliff on macOS." Testing this empirically would
require a full project sync, but the concern is documented across multiple
sources: virtiofs on macOS with Lima has historically had stability issues and
throughput degradation under heavy I/O (especially with many small files).
This has improved in recent Lima + macOS versions but is not as battle-tested as
the reverse-sshfs path.

### Mutagen's tradeoff

Mutagen's project sync session:
- **Pros**: native I/O at full disk speed inside the VM; no FUSE overhead;
  Mutagen handles conflict detection; reliable, well-understood behavior.
- **Cons**: initial two-way sync takes time on large trees (first session only);
  host daemon must be running; a daemon crash leaves sync half-done; large
  `node_modules` trees generate many sync events.

For this project's profile (code + builds + AI agent artifacts), the initial
sync cost is acceptable and the I/O performance advantage is real. Mutagen's
corner cases (very large trees, many tiny files) apply but are manageable with
`.gitignore`-style ignore patterns on the sync session.

### Hybrid option (not in v1 scope)

A future optimization could layer them: virtiofs for initial browse/compile,
Mutagen as a fallback for I/O-heavy workloads. Not pursuing in v1.

## Decision

**Keep Mutagen as specified.** The spec rationale holds:

- virtiofs performance on macOS is not fully trusted
- Mutagen's I/O speed inside the VM is critical for `node_modules`, compilation
- Mutagen is available via Nix with zero Homebrew dep
- The daemon requirement is acceptable (already managing Lima daemon)

Phase 6's implementation will configure Mutagen with appropriate ignore patterns
(`.git`, `node_modules`, `.cache`, build artifacts) to minimize sync overhead.

## Open follow-ups

- Measure Mutagen initial sync time on the largest real project once Phase 2–3
  are wired and we can run a live sync session end-to-end. Adjust if it's
  prohibitively slow.
- If Mutagen proves unreliable in practice (crashes, missed sync events), the
  virtiofs path is available and can be swapped in for Phase 6 retroactively.
  Lima's `--mount-type` is a per-session flag.