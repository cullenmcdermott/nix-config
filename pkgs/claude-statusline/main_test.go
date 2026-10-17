package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
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

func TestStaleCacheServedOnFetchFailure(t *testing.T) {
	// No credentials and no PATH, so the fetch fails without touching the network.
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, "cache"))
	t.Setenv("PATH", "")
	file := usageCachePath()
	if err := os.WriteFile(file, []byte(`{"five_hour":{"utilization":42}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	old := time.Now().Add(-time.Hour)
	if err := os.Chtimes(file, old, old); err != nil {
		t.Fatal(err)
	}
	if u := getUsage(); u == nil || u.FiveHour.Utilization != 42 {
		t.Fatal("stale cache not served when fetch fails")
	}
	if fi, _ := os.Stat(file); time.Since(fi.ModTime()) > time.Minute {
		t.Fatal("stale cache mtime not bumped; API would be retried every render")
	}
}

func TestFmtReset(t *testing.T) {
	if fmtReset("2026-10-17T20:00:00.123456+00:00") == "N/A" {
		t.Fatal("fractional-second RFC 3339 not parsed")
	}
	if fmtReset("") != "N/A" {
		t.Fatal("empty reset should be N/A")
	}
}
