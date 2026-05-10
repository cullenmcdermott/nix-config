package cli

import (
	"path/filepath"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

// HostClaudeMountRoot is where host-side ~/.claude subpaths land inside the
// VM. The first-boot bind-mount unit then rebinds them onto ~/.claude/<sub>.
const HostClaudeMountRoot = "/var/sandbox/host-claude"

// claudeSubpaths are the read-only paths from ~/.claude that Claude Code reads.
// Anything not in this list is writable and lives on persistent VM state.
var claudeSubpaths = []struct {
	rel string
}{
	{"skills"},
	{"commands"},
	{"agents"},
	{"hooks"},
	{"CLAUDE.md"},
	{"settings.json"},
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
			SyncMode: backend.SyncVirtiofs,
		},
	}
	for _, sub := range claudeSubpaths {
		out = append(out, backend.Mount{
			HostPath: filepath.Join(homeDir, ".claude", sub.rel),
			VMPath:   filepath.Join(HostClaudeMountRoot, sub.rel),
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