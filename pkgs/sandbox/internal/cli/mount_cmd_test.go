package cli

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

func TestMountAdd_AppendsToConfig(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "mount", "add", "/Users/alice/data")
	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsConfigDir, "*", "config.toml"))
	if len(matches) != 1 {
		t.Fatalf("expected 1 config, got %d", len(matches))
	}
	v, err := config.LoadPerVM(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, m := range v.Mounts {
		if m.HostPath == "/Users/alice/data" && m.VMPath == "/Users/alice/data" && m.Writable {
			found = true
		}
	}
	if !found {
		t.Errorf("mount not added: %+v", v.Mounts)
	}
}

func TestMountAdd_PrintsRestartHint(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "mount", "add", "/Users/alice/data")
	if !strings.Contains(strings.ToLower(out), "restart") {
		t.Errorf("expected restart hint in output, got %q", out)
	}
}

func TestMountRm_RemovesEntry(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "mount", "add", "/Users/alice/data")
	_ = runSubcommand(t, app, "mount", "rm", "/Users/alice/data")
	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsConfigDir, "*", "config.toml"))
	v, _ := config.LoadPerVM(matches[0])
	if len(v.Mounts) != 0 {
		t.Errorf("mount not removed: %+v", v.Mounts)
	}
}
