package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestUsageUsesPrivateCache(t *testing.T) {
	// Isolate both supported cache roots and prevent keychain commands on a miss.
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, "cache"))
	t.Setenv("PATH", "")
	root, err := os.UserCacheDir()
	if err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(root, "claude-statusline")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "usage-cache.json"), []byte(`{"five_hour":{"utilization":12.3456}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	usage := getUsage()
	if usage == nil || usage.FiveHour.Utilization != 12.3456 {
		t.Fatal("usage was not read from the isolated user cache")
	}
	info, err := os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o700 {
		t.Fatal("cache directory is not private")
	}
}
