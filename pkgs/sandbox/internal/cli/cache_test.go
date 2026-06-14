package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCacheSync_RequiresRunningVM(t *testing.T) {
	app := newTestApp(t)
	// No VM has been started: state is NEW. `sandbox cache sync` must fail
	// cleanly without invoking nix.
	cmd := NewRootForApp(app)
	cmd.SetArgs([]string{"cache", "sync"})
	var buf strings.Builder
	cmd.SetOut(&buf)
	cmd.SetErr(&buf)
	err := cmd.Execute()
	if err == nil {
		t.Fatalf("expected error when VM is not RUNNING, got nil; output=%q", buf.String())
	}
	if !strings.Contains(strings.ToUpper(err.Error()), "RUNNING") {
		t.Errorf("error %q does not mention RUNNING requirement", err)
	}
}

func TestCacheInfo_ReportsEmptyCache(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "cache", "info")
	if !strings.Contains(out, "cache dir:") {
		t.Errorf("missing cache dir line: %q", out)
	}
	if !strings.Contains(out, "narinfos:    0") {
		t.Errorf("expected 0 narinfos on empty cache: %q", out)
	}
}

func TestCacheInfo_CountsNarinfos(t *testing.T) {
	app := newTestApp(t)
	// Drop a couple of fake narinfo files into the cache dir.
	if err := os.MkdirAll(app.Paths.NixCacheDir, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"a.narinfo", "b.narinfo", "ignored.txt"} {
		if err := os.WriteFile(filepath.Join(app.Paths.NixCacheDir, name), []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	out := runSubcommand(t, app, "cache", "info")
	if !strings.Contains(out, "narinfos:    2") {
		t.Errorf("expected 2 narinfos, got: %q", out)
	}
}
