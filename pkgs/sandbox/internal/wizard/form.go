// Package wizard captures the first-run TUI as a pure Form value plus a
// huh-based renderer. Form is data-only so it can be unit-tested.
package wizard

import (
	"fmt"
	"strings"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

type Form struct {
	CPUs        int
	MemoryGiB   int
	DiskGiB     int
	Arch        string
	Agent       string
	ExtraMounts []string
}

// In v1 only `claude` is selectable. The wizard surfaces `codex`/`omp` as
// disabled options to telegraph the roadmap; selection still rejects them.
var supportedAgents = map[string]bool{
	"claude": true,
}

var supportedArches = map[string]bool{
	"aarch64": true,
	"x86_64":  true,
}

func NewForm(g config.Global) Form {
	arch := g.Arch
	if arch == "" {
		arch = "aarch64"
	}
	return Form{
		CPUs:      g.CPUs,
		MemoryGiB: g.MemoryGiB,
		DiskGiB:   g.DiskGiB,
		Arch:      arch,
		Agent:     g.Agent,
	}
}

func (f Form) Validate() error {
	if f.CPUs <= 0 {
		return fmt.Errorf("cpus must be > 0")
	}
	if f.MemoryGiB <= 0 {
		return fmt.Errorf("memory must be > 0")
	}
	if f.DiskGiB <= 0 {
		return fmt.Errorf("disk must be > 0")
	}
	if !supportedArches[f.Arch] {
		return fmt.Errorf("arch must be aarch64 or x86_64 (got %q)", f.Arch)
	}
	if !supportedAgents[f.Agent] {
		return fmt.Errorf("agent %q not supported in v1 (only `claude`)", f.Agent)
	}
	return nil
}

// Apply turns the form into a PerVM config write.
func (f Form) Apply() config.PerVM {
	mounts := make([]config.Mount, 0, len(f.ExtraMounts))
	for _, p := range f.ExtraMounts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		mounts = append(mounts, config.Mount{HostPath: p, VMPath: p, Writable: true})
	}
	return config.PerVM{
		CPUs:      f.CPUs,
		MemoryGiB: f.MemoryGiB,
		DiskGiB:   f.DiskGiB,
		Arch:      f.Arch,
		Agent:     f.Agent,
		Mounts:    mounts,
	}
}
