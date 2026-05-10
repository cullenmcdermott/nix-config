package lima

import (
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

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