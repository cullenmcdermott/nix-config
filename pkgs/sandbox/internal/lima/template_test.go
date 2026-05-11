package lima

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v3"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

// limaSchema mirrors the relevant fields of a Lima YAML file for round-trip
// testing. Field names match Lima's camelCase YAML keys.
type limaSchema struct {
	VMType    string `yaml:"vmType"`
	CPUs      int    `yaml:"cpus"`
	Memory    string `yaml:"memory"`
	Disk      string `yaml:"disk"`
	MountType string `yaml:"mountType"`
	Mounts    []struct {
		Location   string `yaml:"location"`
		MountPoint string `yaml:"mountPoint"`
		Writable   bool   `yaml:"writable"`
	} `yaml:"mounts"`
	Provision []struct {
		Mode   string `yaml:"mode"`
		Script string `yaml:"script"`
	} `yaml:"provision"`
}

func TestRenderTemplate_Minimal(t *testing.T) {
	spec := backend.VMSpec{
		ID:        "demo-abcdef",
		CPUs:      4,
		MemoryMiB: 8192,
		DiskGiB:   50,
		Arch:      "aarch64",
		Mounts:    nil,
		Provision: backend.ProvisionScript{},
	}
	got, err := RenderTemplate(spec)
	if err != nil {
		t.Fatal(err)
	}
	for _, must := range []string{
		"vmType: vz",
		"cpus: 4",
		"memory: 8GiB",
		"disk: 50GiB",
		"arch: aarch64",
		"ubuntu-24.04-minimal-cloudimg-arm64.img",
	} {
		if !strings.Contains(got, must) {
			t.Errorf("rendered yaml missing %q\n%s", must, got)
		}
	}
	// No mounts or provision when spec has none.
	if strings.Contains(got, "mounts:") {
		t.Errorf("yaml should not have mounts section with empty mounts")
	}
	if strings.Contains(got, "provision:") {
		t.Errorf("yaml should not have provision section when script is empty")
	}
}

func TestRenderTemplate_WithMounts_FiltersMutagen(t *testing.T) {
	spec := backend.VMSpec{
		ID:   "test-123456",
		CPUs: 4, MemoryMiB: 8192, DiskGiB: 50, Arch: "aarch64",
		Mounts: []backend.Mount{
			{HostPath: "/Users/alice/proj", VMPath: "/Users/alice/proj", Writable: true, SyncMode: backend.SyncMutagen},
			{HostPath: "/Users/alice/.claude/skills", VMPath: "/var/sandbox/host-claude/skills", Writable: false, SyncMode: backend.SyncVirtiofs},
			{HostPath: "/Users/alice/.claude/CLAUDE.md", VMPath: "/var/sandbox/host-claude/CLAUDE.md", Writable: false, SyncMode: backend.SyncVirtiofs},
		},
		Provision: backend.ProvisionScript{},
	}
	got, err := RenderTemplate(spec)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "mounts:") {
		t.Errorf("yaml missing mounts section")
	}
	if !strings.Contains(got, "mountType: virtiofs") {
		t.Errorf("yaml missing mountType: virtiofs")
	}
	// Project mount (Mutagen) must NOT appear in lima.yaml.
	if strings.Contains(got, `location: "/Users/alice/proj"`) {
		t.Errorf("project Mutagen mount should not appear in lima.yaml")
	}
	// Skills and CLAUDE.md should still appear.
	if !strings.Contains(got, `location: "/Users/alice/.claude/skills"`) {
		t.Errorf("missing skills mount in rendered yaml")
	}
	if !strings.Contains(got, "mountPoint: \"/var/sandbox/host-claude/CLAUDE.md\"") {
		t.Errorf("missing CLAUDE.md mount point in rendered yaml")
	}
}

func TestRenderTemplate_WithProvision(t *testing.T) {
	spec := backend.VMSpec{
		ID:   "prov-789abc",
		CPUs: 2, MemoryMiB: 4096, DiskGiB: 20, Arch: "aarch64",
		Provision: backend.ProvisionScript{
			Script: "echo hello world",
		},
	}
	got, err := RenderTemplate(spec)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "provision:") {
		t.Errorf("yaml missing provision section:\n%s", got)
	}
	if !strings.Contains(got, "mode: system") {
		t.Errorf("yaml missing provision mode:\n%s", got)
	}
	if !strings.Contains(got, "script: |") {
		t.Errorf("yaml missing script literal:\n%s", got)
	}
	if !strings.Contains(got, "echo hello world") {
		t.Errorf("yaml missing provision script content:\n%s", got)
	}
}

func TestRenderTemplate_MultiLineProvision_EmitsOneEntry(t *testing.T) {
	script := "#!/bin/bash\nset -euo pipefail\nmkdir -p /tmp/foo\necho done"
	spec := backend.VMSpec{
		ID:   "ml-test-abc123",
		CPUs: 2, MemoryMiB: 4096, DiskGiB: 20, Arch: "aarch64",
		Provision: backend.ProvisionScript{Script: script},
	}
	got, err := RenderTemplate(spec)
	if err != nil {
		t.Fatal(err)
	}
	if count := strings.Count(got, "- mode: system"); count != 1 {
		t.Errorf("expected exactly 1 provision entry, got %d:\n%s", count, got)
	}
	if !strings.Contains(got, "\n") {
		t.Error("provision script body should contain newlines")
	}
	if !strings.Contains(got, "set -euo pipefail") {
		t.Errorf("provision script body missing expected content:\n%s", got)
	}
}

func TestRenderTemplate_AMD64Image(t *testing.T) {
	got, err := RenderTemplate(backend.VMSpec{ID: "x", CPUs: 1, MemoryMiB: 1024, DiskGiB: 10, Arch: "x86_64"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "amd64.img") {
		t.Errorf("expected amd64 image, got:\n%s", got)
	}
	if !strings.Contains(got, "arch: x86_64") {
		t.Errorf("expected x86_64 arch, got:\n%s", got)
	}
}

func TestRenderTemplate_RejectsUnknownArch(t *testing.T) {
	_, err := RenderTemplate(backend.VMSpec{ID: "x", CPUs: 1, MemoryMiB: 1024, DiskGiB: 10, Arch: "riscv"})
	if err == nil {
		t.Fatal("expected error for unsupported arch")
	}
}

// TestRenderTemplate_YAMLRoundTrip parses the rendered YAML through a real
// YAML decoder to catch shape regressions (e.g. P3-1's per-line splitting).
func TestRenderTemplate_YAMLRoundTrip(t *testing.T) {
	script := "#!/bin/bash\nset -euo pipefail\nmkdir -p /tmp/foo\necho done\n"
	spec := backend.VMSpec{
		ID:        "rt-abcdef",
		CPUs:      4,
		MemoryMiB: 8192,
		DiskGiB:   50,
		Arch:      "aarch64",
		Mounts: []backend.Mount{
			// Mutagen-managed: must not appear in lima.yaml.
			{HostPath: "/Users/alice/proj", VMPath: "/Users/alice/proj", Writable: true, SyncMode: backend.SyncMutagen},
			// Virtiofs: must appear in lima.yaml.
			{HostPath: "/Users/alice/.claude/skills", VMPath: "/var/sandbox/host-claude/skills", Writable: false, SyncMode: backend.SyncVirtiofs},
			{HostPath: "/Users/alice/.claude/CLAUDE.md", VMPath: "/var/sandbox/host-claude/CLAUDE.md", Writable: false, SyncMode: backend.SyncVirtiofs},
		},
		Provision: backend.ProvisionScript{Script: script},
	}

	rendered, err := RenderTemplate(spec)
	if err != nil {
		t.Fatalf("RenderTemplate: %v", err)
	}

	var out limaSchema
	if err := yaml.Unmarshal([]byte(rendered), &out); err != nil {
		t.Fatalf("yaml.Unmarshal failed: %v\nrendered:\n%s", err, rendered)
	}

	// Provision: exactly one entry whose script body contains newlines.
	if len(out.Provision) != 1 {
		t.Errorf("expected 1 provision entry, got %d (P3-1 regression)", len(out.Provision))
	} else {
		if !strings.Contains(out.Provision[0].Script, "\n") {
			t.Errorf("provision script body has no newlines; full script: %q", out.Provision[0].Script)
		}
		if out.Provision[0].Mode != "system" {
			t.Errorf("provision mode = %q, want system", out.Provision[0].Mode)
		}
	}

	// Mounts: only virtiofs mounts appear (Mutagen mount filtered out).
	if len(out.Mounts) != 2 {
		t.Errorf("expected 2 virtiofs mounts, got %d", len(out.Mounts))
	}
	for _, m := range out.Mounts {
		if m.Location == "/Users/alice/proj" {
			t.Error("Mutagen-managed project mount must not appear in lima.yaml")
		}
	}
	if out.MountType != "virtiofs" {
		t.Errorf("mountType = %q, want virtiofs", out.MountType)
	}
}
