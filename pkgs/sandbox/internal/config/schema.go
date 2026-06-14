// Package config defines and loads the global + per-VM TOML config schemas.
package config

type Mount struct {
	HostPath string `toml:"host_path"`
	VMPath   string `toml:"vm_path"`
	Writable bool   `toml:"writable"`
}

// Bridge holds host-side bridge daemon settings. It only appears in the global
// config (not per-VM): the allowlist is a host-trust decision, not a per-VM
// one. An empty OpAllow denies every `op read` over the bridge.
type Bridge struct {
	// OpAllow lists allowed 1Password ref patterns (e.g. "op://Private/*").
	// See bridge.allowRef for matching semantics. Empty = deny all.
	OpAllow []string `toml:"op_allow"`
}

// Global defaults live in ~/.config/sandbox/config.toml. Every field has a
// default; missing files are equivalent to all-defaults.
type Global struct {
	CPUs      int    `toml:"cpus"`
	MemoryGiB int    `toml:"memory_gib"`
	DiskGiB   int    `toml:"disk_gib"`
	Arch      string `toml:"arch"`
	Agent     string `toml:"agent"`
	Bridge    Bridge `toml:"bridge"`
}

func DefaultGlobal() Global {
	return Global{
		CPUs:      4,
		MemoryGiB: 8,
		DiskGiB:   50,
		Arch:      "", // empty means "host arch"
		Agent:     "claude",
		// Bridge is intentionally zero-valued: empty OpAllow denies all op reads.
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
	// SyncGit syncs .git into the VM (two-way), letting agents run git there.
	// Off by default: concurrent host+VM git activity can produce Mutagen
	// conflicts on refs/index. Takes effect on the next `sandbox start` — the
	// project sync session is recreated when this changes.
	SyncGit bool `toml:"sync_git,omitempty"`
}

type Resolved struct {
	CPUs      int     `toml:"cpus"`
	MemoryGiB int     `toml:"memory_gib"`
	DiskGiB   int     `toml:"disk_gib"`
	Arch      string  `toml:"arch"`
	Agent     string  `toml:"agent"`
	Mounts    []Mount `toml:"mounts"`
	SyncGit   bool    `toml:"sync_git"`
}
