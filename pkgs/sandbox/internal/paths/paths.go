// Package paths centralizes every host-side path the sandbox CLI uses.
package paths

import (
	"fmt"
	"os"
	"path/filepath"
)

type Paths struct {
	Home             string
	ConfigDir        string // ~/.config/sandbox
	GlobalConfig     string // ~/.config/sandbox/config.toml
	VMsConfigDir     string // ~/.config/sandbox/vms
	DataDir          string // ~/.local/share/sandbox
	VMsDataDir       string // ~/.local/share/sandbox/vms
	CredentialsDir   string // ~/.local/share/sandbox/credentials (writable-mounted into VMs; persists LLM auth across rebuilds)
	NixCacheDir      string // ~/.local/share/sandbox/nix-cache (RO-mounted into VMs)
	NixCacheKey      string // ~/.local/share/sandbox/nix-cache-key.sec (signing key; NOT mounted into VMs)
	ImagesCacheDir   string // ~/.cache/sandbox/images
	MountHistoryFile string // ~/.local/share/sandbox/mount-history.json
}

func Resolve() (*Paths, error) {
	home := os.Getenv("HOME")
	if home == "" {
		return nil, fmt.Errorf("$HOME is empty")
	}
	cfg := xdg("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dat := xdg("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	cch := xdg("XDG_CACHE_HOME", filepath.Join(home, ".cache"))

	configDir := filepath.Join(cfg, "sandbox")
	dataDir := filepath.Join(dat, "sandbox")
	imagesDir := filepath.Join(cch, "sandbox", "images")
	// NixCacheKey lives in DataDir but OUTSIDE NixCacheDir, because
	// NixCacheDir is mounted into every VM and the secret must never be
	// VM-visible.
	nixCacheDir := filepath.Join(dataDir, "nix-cache")

	return &Paths{
		Home:             home,
		ConfigDir:        configDir,
		GlobalConfig:     filepath.Join(configDir, "config.toml"),
		VMsConfigDir:     filepath.Join(configDir, "vms"),
		DataDir:          dataDir,
		VMsDataDir:       filepath.Join(dataDir, "vms"),
		CredentialsDir:   filepath.Join(dataDir, "credentials"),
		NixCacheDir:      nixCacheDir,
		NixCacheKey:      filepath.Join(dataDir, "nix-cache-key.sec"),
		ImagesCacheDir:   imagesDir,
		MountHistoryFile: filepath.Join(dataDir, "mount-history.json"),
	}, nil
}

func xdg(envKey, fallback string) string {
	if v := os.Getenv(envKey); v != "" {
		return v
	}
	return fallback
}

// VM returns the per-VM subset of paths.
type VMPaths struct {
	ConfigDir           string
	ConfigFile          string
	LimaYAML            string
	DataDir             string
	StateFile           string
	BridgeSocket        string
	BridgeToken         string
	MutagenSessionsFile string
}

func (p *Paths) VM(id string) VMPaths {
	cfg := filepath.Join(p.VMsConfigDir, id)
	dat := filepath.Join(p.VMsDataDir, id)
	return VMPaths{
		ConfigDir:           cfg,
		ConfigFile:          filepath.Join(cfg, "config.toml"),
		LimaYAML:            filepath.Join(cfg, "lima.yaml"),
		DataDir:             dat,
		StateFile:           filepath.Join(dat, "state.json"),
		BridgeSocket:        filepath.Join(dat, "bridge.sock"),
		BridgeToken:         filepath.Join(dat, "bridge.token"),
		MutagenSessionsFile: filepath.Join(dat, "mutagen.sessions"),
	}
}

// EnsureDirs creates the host-side directories the sandbox needs at startup.
// Idempotent. Directories are created with 0o700 (owner-only) permissions since
// they eventually hold bridge.token and bridge.sock — sensitive files.
func (p *Paths) EnsureDirs() error {
	for _, d := range []string{p.ConfigDir, p.VMsConfigDir, p.DataDir, p.VMsDataDir, p.CredentialsDir, p.NixCacheDir, p.ImagesCacheDir} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			return fmt.Errorf("mkdir %s: %w", d, err)
		}
	}
	return nil
}
