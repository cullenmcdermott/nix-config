package config

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestDefaults(t *testing.T) {
	g := DefaultGlobal()
	if g.CPUs != 4 {
		t.Errorf("CPUs default = %d, want 4", g.CPUs)
	}
	if g.MemoryGiB != 8 {
		t.Errorf("MemoryGiB default = %d, want 8", g.MemoryGiB)
	}
	if g.DiskGiB != 50 {
		t.Errorf("DiskGiB default = %d, want 50", g.DiskGiB)
	}
	if g.Agent != "claude" {
		t.Errorf("Agent default = %q, want %q", g.Agent, "claude")
	}
}

func TestLoadResolved_GlobalOnly(t *testing.T) {
	dir := t.TempDir()
	gPath := filepath.Join(dir, "config.toml")
	mustWrite(t, gPath, "cpus = 6\nmemory_gib = 12\n")

	r, err := LoadResolved(gPath, "")
	if err != nil {
		t.Fatal(err)
	}
	if r.CPUs != 6 || r.MemoryGiB != 12 {
		t.Errorf("global override not applied: %+v", r)
	}
	if r.DiskGiB != 50 {
		t.Errorf("non-overridden field lost default: %d", r.DiskGiB)
	}
}

func TestLoadResolved_PerVMOverridesGlobal(t *testing.T) {
	dir := t.TempDir()
	gPath := filepath.Join(dir, "config.toml")
	vPath := filepath.Join(dir, "vm-config.toml")
	mustWrite(t, gPath, "cpus = 6\nmemory_gib = 12\n")
	mustWrite(t, vPath, "cpus = 2\ndisk_gib = 100\n[[mounts]]\nhost_path = \"/Users/alice/data\"\nvm_path = \"/Users/alice/data\"\nwritable = true\n")

	r, err := LoadResolved(gPath, vPath)
	if err != nil {
		t.Fatal(err)
	}
	if r.CPUs != 2 {
		t.Errorf("per-VM did not override global: %d", r.CPUs)
	}
	if r.MemoryGiB != 12 {
		t.Errorf("global value lost when per-VM does not set it: %d", r.MemoryGiB)
	}
	if r.DiskGiB != 100 {
		t.Errorf("disk_gib not loaded: %d", r.DiskGiB)
	}
	if len(r.Mounts) != 1 || r.Mounts[0].HostPath != "/Users/alice/data" {
		t.Errorf("mounts not loaded: %+v", r.Mounts)
	}
}

func TestSavePerVM_RoundTrip(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "config.toml")
	v := PerVM{CPUs: 8, MemoryGiB: 16, DiskGiB: 200, Agent: "claude"}
	if err := SavePerVM(p, v); err != nil {
		t.Fatal(err)
	}
	got, err := LoadPerVM(p)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, v) {
		t.Errorf("round-trip mismatch: %+v vs %+v", got, v)
	}
}

func mustWrite(t *testing.T, path, contents string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
		t.Fatal(err)
	}
}
