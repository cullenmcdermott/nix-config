package cli

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestConfigPrint_Defaults(t *testing.T) {
	app := newTestApp(t)
	body := runSubcommand(t, app, "config")
	for _, want := range []string{"cpus = 4", "memory_gib = 8", "disk_gib = 50", "agent = 'claude'"} {
		if !strings.Contains(body, want) {
			t.Errorf("config output missing %q\n%s", want, body)
		}
	}
}

func TestConfigEdit_CreatesFileIfMissing(t *testing.T) {
	app := newTestApp(t)
	// Use `true` as the editor — exits 0 without modifying the file.
	t.Setenv("EDITOR", "true")
	t.Setenv("VISUAL", "")

	_ = runSubcommand(t, app, "config", "edit")

	matches, err := filepath.Glob(filepath.Join(app.Paths.VMsConfigDir, "*", "config.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected 1 config.toml, found %d: %v", len(matches), matches)
	}
}
