// Package backend defines the VM backend contract.
//
// One backend ships in v1 (lima). The interface stays small on purpose —
// vfkit/krunvm/Firecracker would each implement the same surface.
package backend

import "context"

type VMID string

type Status string

const (
	StatusUnknown Status = "UNKNOWN"
	StatusStopped Status = "STOPPED"
	StatusRunning Status = "RUNNING"
	StatusFailed  Status = "FAILED"
	StatusGone    Status = "GONE"
)

type SyncMode string

const (
	SyncVirtiofs SyncMode = "virtiofs"
	SyncMutagen  SyncMode = "mutagen"
)

type Mount struct {
	HostPath string
	VMPath   string
	Writable bool
	SyncMode SyncMode
}

// VMSpec is the create-time specification for a backend VM.
//
// Provisioning is intentionally a black-box []byte: each phase that adds
// provisioning content (Phase 7+) appends to it; the backend just embeds it.
type VMSpec struct {
	ID        VMID
	CPUs      int
	MemoryMiB int
	DiskGiB   int
	Arch      string // "aarch64" | "x86_64"
	Mounts    []Mount
	Provision ProvisionScript
}

type ProvisionScript struct {
	// Inline shell script run as root on first boot. Empty in Phase 3a.
	Script string
}

type SSHConfig struct {
	// Path to a Lima-generated ssh_config file.
	ConfigFile string
	// Host alias to use with `ssh -F <ConfigFile> <Host>`.
	Host string
}

type VMInfo struct {
	ID     VMID
	Status Status
}

type Backend interface {
	Create(ctx context.Context, spec VMSpec) error
	Start(ctx context.Context, id VMID) error
	Stop(ctx context.Context, id VMID) error
	Destroy(ctx context.Context, id VMID) error
	Status(ctx context.Context, id VMID) (Status, error)
	SSHConfig(ctx context.Context, id VMID) (SSHConfig, error)
	List(ctx context.Context) ([]VMInfo, error)
}
