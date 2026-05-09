# Spike: APFS reflink across Lima qcow2 disks

**Date:** 2026-05-09
**Drives:** Phase 8 (warm `/nix` cache strategy)
**Status:** resolved

## Question

Does `cp --reflink=auto` of Lima's data dir produce block-sharing on APFS? If yes, a
"clone VM dir → use as warm template" strategy saves disk space per new VM. If no,
we need a different Phase 8 approach.

## Experiment

### Setup
- Lima driver: `vz` (Apple Silicon)
- VM: `reflink-spike` (Ubuntu 24.04 arm64), freshly provisioned
- Populated `/nix` with `hello`, `jq`, `ripgrep`, `fd`, `bat` → 767M `/nix` footprint
- Lima data dir layout:
  - `basedisk`: QCOW2 base image (3.7G, read-only backing)
  - `diffdisk`: raw pre-allocated disk (100G capacity, 3.4G allocated)
  - `cidata.iso`, `lima.yaml`, sockets, logs

### Test 1 — Clone full Lima data dir

```
cp --reflink=auto -R ~/.lima/reflink-spike /tmp/reflink-target
```

Result: **sockets and special files fail** (permission denied in tmp), but the
critical files copy. Disk consumption delta: **0 bytes** reported by `df`, but
actual inode numbers differ (same inode = reflink; different = full copy).

- `diffdisk`: src ino=51576793, dst ino=51577308 — **different inodes, NOT reflinked**
- Same test on the `diffdisk` alone: 3.4G source, 0 bytes `df` delta, different inodes

**Conclusion: APFS refuses to reflink the diffdisk despite `--reflink=auto`.**

### Test 2 — APFS reflink control test

Regular files created by `dd if=/dev/urandom of=... bs=1M count=100`:

```
cp --reflink=auto bigfile clone
→ src ino=51577409, dst ino=51577410
→ NOT reflinked
```

### Test 3 — Truncate + cp (known reflinkable pattern on APFS)

```
truncate -s 1G file
cp --reflink=auto file clone
→ same inode number = YES
```

**APFS reflink works for sparse/truncated files, not for data-written files.**

### Test 4 — Lima diffdisk internals

`diffdisk` is a **DOS/MBR boot sector** raw disk image, 100G pre-allocated via
`qemu-img create -f raw`. Even though it contains a filesystem with mostly empty
blocks, the raw file has data in it. APFS sees a non-sparse regular file and
won't reflink.

## Finding

**APFS `cp --reflink=auto` does not share blocks for Lima's `diffdisk` images.**
The raw disk image is a regular file with written data; APFS's clone-on-write
does not trigger for this file type.

This means the warm-template clone strategy described in Phase 8 will not save
disk space via APFS reflink. Each new project VM would clone the full diffdisk
(~3–5G with warm `/nix`) at full cost.

## Impact on Phase 8

The Phase 8 warm `/nix` strategy must use a different approach:

**Option A — NFS-style read-only bind mount from warm VM (recommended)**
Keep one "warm template" VM running or mountable. New VMs bind-mount the warm
VM's `/nix` as read-only at startup. No copy needed. Requires the warm VM to be
running or have its disk accessible. Compatible with Lima's existing networking.

**Option B — Accept the cost**
If disk is not a concern (3–5G per project VM, ~10 projects = 30–50G), accept
the clone cost. The copy is fast (copy-on-write at the block device level inside
the VM's own disk is fast for sequential writes) and deduplicates at the block
level within each VM's own disk.

**Option C — `nix-serve` substituter**
Use `nix copy --to ...` with a local `nix-serve` instance running in a warm VM.
Phase 8 spec already mentions this as a later optimization. This doesn't save
disk on the host (stores the narinfos + nar files) but avoids re-downloading.

## Decision

Pursue Option A (read-only bind mount from a warm template VM) in Phase 8. The
warm VM is long-running anyway for the first project; share its `/nix` with
subsequent projects. If the warm VM is stopped, fall back to Option B (full
clone) with the cost documented.

## Open follow-ups

- Does Lima support sharing a backing file between instances? If the warm VM
  uses a qcow2 snapshot chain with a shared backing store, that COULD share the
  `/nix` blocks without full clone cost. Investigate in Phase 8 if Lima's
  instance cloning or `limactl copy` supports snapshot-backed clones.
- The `nix-serve` approach (Option C) is worth revisiting once the Phase 8
  implementation lands and we can measure actual download time vs. clone time.