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
	for _, mustNot := range []string{"mounts:", "provision:"} {
		if strings.Contains(got, mustNot) {
			t.Errorf("rendered yaml contained %q in Phase 3a; should be empty", mustNot)
		}
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
