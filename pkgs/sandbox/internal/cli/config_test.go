package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestConfigPrint_Defaults(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	wd := t.TempDir()
	cwd, _ := os.Getwd()
	t.Cleanup(func() { _ = os.Chdir(cwd) })
	_ = os.Chdir(wd)

	cmd := NewRoot()
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs([]string{"config"})
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	body := out.String()
	for _, want := range []string{"cpus = 4", "memory_gib = 8", "disk_gib = 50", "agent = 'claude'"} {
		if !strings.Contains(body, want) {
			t.Errorf("config output missing %q\n%s", want, body)
		}
	}
}

func TestConfigEdit_CreatesFileIfMissing(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	wd := t.TempDir()
	cwd, _ := os.Getwd()
	t.Cleanup(func() { _ = os.Chdir(cwd) })
	_ = os.Chdir(wd)

	// Use `true` as the editor — exits 0 without modifying the file.
	t.Setenv("EDITOR", "true")
	t.Setenv("VISUAL", "")

	cmd := NewRoot()
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs([]string{"config", "edit"})
	if err := cmd.Execute(); err != nil {
		t.Fatalf("Execute: %v\n%s", err, out.String())
	}

	// Walk ~/.config/sandbox/vms/<id>/config.toml — there should be exactly one.
	matches, err := filepath.Glob(filepath.Join(home, ".config", "sandbox", "vms", "*", "config.toml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected 1 config.toml, found %d: %v", len(matches), matches)
	}
}
