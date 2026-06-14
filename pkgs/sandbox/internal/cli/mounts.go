package cli

import (
	"os"
	"path/filepath"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

// HostClaudeMountRoot is where host-side ~/.claude subpaths land inside the
// VM. The first-boot bind-mount unit then rebinds them onto ~/.claude/<sub>.
const HostClaudeMountRoot = "/var/sandbox/host-claude"

// NixCacheVMPath is where the host-side shared Nix binary cache is RO-mounted
// inside the VM. The provision script configures nix-daemon to use it as a
// substituter via file:// in /etc/nix/nix.conf.
const NixCacheVMPath = "/var/sandbox/nix-cache"

// HostOmpMountRoot is where host-side ~/.config/omp/agent subpaths land inside
// the VM. The first-boot bind-mount unit rebinds them onto ~/.config/omp/agent/<sub>.
const HostOmpMountRoot = "/var/sandbox/host-omp"

// CredentialsVMPath is where the host-side persistent credential store is
// mounted (writable) inside the VM. The provision script symlinks each tool's
// auth file (~/.claude/.credentials.json, ~/.codex/auth.json) into it so logins
// survive VM rebuilds. Shared across all VMs — auth is per-user, not per-project.
const CredentialsVMPath = "/var/sandbox/credentials"

// claudeSubpaths are the read-only paths from ~/.claude that are overlaid
// read-only into the VM. These must be directories (not files). Anything not
// in this list is writable and lives on persistent VM state.
//
// Exported so lima/provision.go can use the same list without duplication.
var ClaudeSubpaths = []string{
	"skills",
	"commands",
	"agents",
	"hooks",
	// "CLAUDE.md" and "settings.json" are omitted: Lima's virtiofs expects
	// directories; regular-file mounts are undefined behavior. Files are
	// copied into the VM by the provision script instead.
}

// OmpSubpaths are the read-only paths from ~/.config/omp/agent/ that are
// overlaid into the VM. These must be directories (not files). Config files
// (config.yml, AGENTS.md) are copied by the provision script instead.
var OmpSubpaths = []string{
	"skills",
	"prompts",
	"extensions",
	"themes",
}

// BuildMounts returns the deterministic mount list for a VM given:
//   - projectPath: absolute host path to the project (git toplevel or cwd)
//   - homeDir: the host user's home directory (for ~/.claude resolution)
//   - extra: per-VM TOML extras
//
// User extras win on VMPath conflicts.
func BuildMounts(projectPath, homeDir string, extra []config.Mount) []backend.Mount {
	out := []backend.Mount{
		{
			HostPath: projectPath,
			VMPath:   projectPath,
			Writable: true,
			SyncMode: backend.SyncMutagen,
		},
	}
	for _, sub := range ClaudeSubpaths {
		hostPath := filepath.Join(homeDir, ".claude", sub)
		if _, err := os.Stat(hostPath); err != nil {
			// Skip subpaths that don't exist on the host. Lima rejects mounts
			// with non-existent source paths.
			continue
		}
		out = append(out, backend.Mount{
			HostPath: hostPath,
			VMPath:   filepath.Join(HostClaudeMountRoot, sub),
			Writable: false,
			SyncMode: backend.SyncVirtiofs,
		})
	}
	for _, sub := range OmpSubpaths {
		hostPath := filepath.Join(homeDir, ".config", "omp", "agent", sub)
		if _, err := os.Stat(hostPath); err != nil {
			continue
		}
		out = append(out, backend.Mount{
			HostPath: hostPath,
			VMPath:   filepath.Join(HostOmpMountRoot, sub),
			Writable: false,
			SyncMode: backend.SyncVirtiofs,
		})
	}
	for _, m := range extra {
		out = append(out, backend.Mount{
			HostPath: m.HostPath,
			VMPath:   m.VMPath,
			Writable: m.Writable,
			SyncMode: backend.SyncVirtiofs,
		})
	}
	// Dedupe by VMPath — last write wins so user extras override.
	seen := map[string]int{}
	deduped := make([]backend.Mount, 0, len(out))
	for _, m := range out {
		if i, ok := seen[m.VMPath]; ok {
			deduped[i] = m
			continue
		}
		seen[m.VMPath] = len(deduped)
		deduped = append(deduped, m)
	}
	return deduped
}

// BuildMountsWithCache is like BuildMounts but also appends a read-only
// virtiofs mount of the host-side Nix binary cache if cacheHostDir is
// non-empty. The cache mount is prepended to extra so BuildMounts'
// last-write-wins dedup lets user-specified overrides at NixCacheVMPath take
// precedence.
//
// The mount is added UNCONDITIONALLY when cacheHostDir != "" — there is no
// has-content gating. An empty cache is just a substituter miss, but gating
// on emptiness would deadlock bootstrap (the cache cannot become non-empty
// until at least one VM successfully populates it).
func BuildMountsWithCache(projectPath, homeDir string, extra []config.Mount, cacheHostDir string) []backend.Mount {
	if cacheHostDir == "" {
		return BuildMounts(projectPath, homeDir, extra)
	}
	// Prepend the cache mount so user extras can override it via dedup.
	autoExtra := append([]config.Mount{{HostPath: cacheHostDir, VMPath: NixCacheVMPath, Writable: false}}, extra...)
	return BuildMounts(projectPath, homeDir, autoExtra)
}
