package paths

import (
	"path/filepath"
	"testing"
)

func TestResolve_DefaultHome(t *testing.T) {
	t.Setenv("HOME", "/Users/alice")
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	p, err := Resolve()
	if err != nil {
		t.Fatal(err)
	}
	checks := map[string]string{
		"ConfigDir":      "/Users/alice/.config/sandbox",
		"GlobalConfig":   "/Users/alice/.config/sandbox/config.toml",
		"DataDir":        "/Users/alice/.local/share/sandbox",
		"NixCacheDir":    "/Users/alice/.local/share/sandbox/nix-cache",
		"NixCacheKey":    "/Users/alice/.local/share/sandbox/nix-cache-key.sec",
		"VMsDataDir":     "/Users/alice/.local/share/sandbox/vms",
		"VMsConfigDir":   "/Users/alice/.config/sandbox/vms",
		"ImagesCacheDir": "/Users/alice/.cache/sandbox/images",
	}
	for name, want := range checks {
		got := map[string]string{
			"ConfigDir":      p.ConfigDir,
			"GlobalConfig":   p.GlobalConfig,
			"DataDir":        p.DataDir,
			"NixCacheDir":    p.NixCacheDir,
			"NixCacheKey":    p.NixCacheKey,
			"VMsDataDir":     p.VMsDataDir,
			"VMsConfigDir":   p.VMsConfigDir,
			"ImagesCacheDir": p.ImagesCacheDir,
		}[name]
		if got != want {
			t.Errorf("%s = %q, want %q", name, got, want)
		}
	}
}

func TestResolve_NixCacheKeyOutsideNixCacheDir(t *testing.T) {
	// The signing key MUST NOT live inside NixCacheDir, because NixCacheDir is
	// RO-mounted into every VM. If the key were inside, VM-side code would
	// be able to read it and forge cache entries.
	t.Setenv("HOME", "/Users/alice")
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	p, err := Resolve()
	if err != nil {
		t.Fatal(err)
	}
	rel, err := filepath.Rel(p.NixCacheDir, p.NixCacheKey)
	if err != nil {
		t.Fatalf("filepath.Rel: %v", err)
	}
	// A path that starts with ".." escapes NixCacheDir (which is what we want).
	if rel != ".." && !startsWith(rel, ".."+string(filepath.Separator)) {
		t.Errorf("NixCacheKey (%q) appears to be inside NixCacheDir (%q); secret would be VM-visible (rel=%q)",
			p.NixCacheKey, p.NixCacheDir, rel)
	}
}

func startsWith(s, prefix string) bool {
	return len(s) >= len(prefix) && s[:len(prefix)] == prefix
}

func TestResolve_RespectsXDG(t *testing.T) {
	t.Setenv("HOME", "/Users/alice")
	t.Setenv("XDG_CONFIG_HOME", "/Users/alice/cfg")
	t.Setenv("XDG_DATA_HOME", "/Users/alice/data")
	t.Setenv("XDG_CACHE_HOME", "/Users/alice/cache")
	p, err := Resolve()
	if err != nil {
		t.Fatal(err)
	}
	if p.ConfigDir != "/Users/alice/cfg/sandbox" {
		t.Errorf("ConfigDir = %q", p.ConfigDir)
	}
	if p.DataDir != "/Users/alice/data/sandbox" {
		t.Errorf("DataDir = %q", p.DataDir)
	}
	if p.ImagesCacheDir != "/Users/alice/cache/sandbox/images" {
		t.Errorf("ImagesCacheDir = %q", p.ImagesCacheDir)
	}
}

func TestVM_Subpaths(t *testing.T) {
	t.Setenv("HOME", "/Users/alice")
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	p, err := Resolve()
	if err != nil {
		t.Fatal(err)
	}
	v := p.VM("myproj-abcdef")
	cases := map[string]string{
		"ConfigDir":     filepath.Join(p.VMsConfigDir, "myproj-abcdef"),
		"ConfigFile":    filepath.Join(p.VMsConfigDir, "myproj-abcdef", "config.toml"),
		"LimaYAML":      filepath.Join(p.VMsConfigDir, "myproj-abcdef", "lima.yaml"),
		"DataDir":       filepath.Join(p.VMsDataDir, "myproj-abcdef"),
		"StateFile":     filepath.Join(p.VMsDataDir, "myproj-abcdef", "state.json"),
		"BridgeSocket":  filepath.Join(p.VMsDataDir, "myproj-abcdef", "bridge.sock"),
		"BridgeToken":   filepath.Join(p.VMsDataDir, "myproj-abcdef", "bridge.token"),
		"MutagenSesIDs": filepath.Join(p.VMsDataDir, "myproj-abcdef", "mutagen.sessions"),
	}
	got := map[string]string{
		"ConfigDir":     v.ConfigDir,
		"ConfigFile":    v.ConfigFile,
		"LimaYAML":      v.LimaYAML,
		"DataDir":       v.DataDir,
		"StateFile":     v.StateFile,
		"BridgeSocket":  v.BridgeSocket,
		"BridgeToken":   v.BridgeToken,
		"MutagenSesIDs": v.MutagenSessionsFile,
	}
	for name, want := range cases {
		if got[name] != want {
			t.Errorf("%s = %q, want %q", name, got[name], want)
		}
	}
}
