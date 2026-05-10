// Package config defines and loads the global + per-VM TOML config schemas.
package config

type Mount struct {
	HostPath string `toml:"host_path"`
	VMPath   string `toml:"vm_path"`
	Writable bool   `toml:"writable"`
}

// Global defaults live in ~/.config/sandbox/config.toml. Every field has a
// default; missing files are equivalent to all-defaults.
type Global struct {
	CPUs      int    `toml:"cpus"`
	MemoryGiB int    `toml:"memory_gib"`
	DiskGiB   int    `toml:"disk_gib"`
	Arch      string `toml:"arch"`
	Agent     string `toml:"agent"`
}

func DefaultGlobal() Global {
	return Global{
		CPUs:      4,
		MemoryGiB: 8,
		DiskGiB:   50,
		Arch:      "", // empty means "host arch"
		Agent:     "claude",
	}
}

// PerVM overrides live in ~/.config/sandbox/vms/<id>/config.toml. Zero values
// mean "inherit from global".
type PerVM struct {
	CPUs      int     `toml:"cpus,omitempty"`
	MemoryGiB int     `toml:"memory_gib,omitempty"`
	DiskGiB   int     `toml:"disk_gib,omitempty"`
	Arch      string  `toml:"arch,omitempty"`
	Agent     string  `toml:"agent,omitempty"`
	Mounts    []Mount `toml:"mounts,omitempty"`
}

// Resolved is the merged view used by the rest of the CLI.
type Resolved struct {
	CPUs      int
	MemoryGiB int
	DiskGiB   int
	Arch      string
	Agent     string
	Mounts    []Mount
}
