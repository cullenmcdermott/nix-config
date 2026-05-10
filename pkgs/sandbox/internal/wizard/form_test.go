package wizard

import (
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

func TestForm_Defaults_FromGlobal(t *testing.T) {
	g := config.Global{CPUs: 6, MemoryGiB: 12, DiskGiB: 100, Arch: "aarch64", Agent: "claude"}
	f := NewForm(g)
	if f.CPUs != 6 {
		t.Errorf("CPUs default = %d", f.CPUs)
	}
	if f.MemoryGiB != 12 {
		t.Errorf("MemoryGiB default = %d", f.MemoryGiB)
	}
	if f.Agent != "claude" {
		t.Errorf("Agent default = %q", f.Agent)
	}
}

func TestForm_Validate_RejectsBadInputs(t *testing.T) {
	f := Form{CPUs: 0, MemoryGiB: 8, DiskGiB: 50, Arch: "aarch64", Agent: "claude"}
	if err := f.Validate(); err == nil || !strings.Contains(err.Error(), "cpus") {
		t.Errorf("expected cpus validation error, got %v", err)
	}
	f = Form{CPUs: 4, MemoryGiB: 0, DiskGiB: 50, Arch: "aarch64", Agent: "claude"}
	if err := f.Validate(); err == nil || !strings.Contains(err.Error(), "memory") {
		t.Errorf("expected memory validation error, got %v", err)
	}
	f = Form{CPUs: 4, MemoryGiB: 8, DiskGiB: 0, Arch: "aarch64", Agent: "claude"}
	if err := f.Validate(); err == nil || !strings.Contains(err.Error(), "disk") {
		t.Errorf("expected disk validation error, got %v", err)
	}
	f = Form{CPUs: 4, MemoryGiB: 8, DiskGiB: 50, Arch: "fnord", Agent: "claude"}
	if err := f.Validate(); err == nil || !strings.Contains(err.Error(), "arch") {
		t.Errorf("expected arch validation error, got %v", err)
	}
	f = Form{CPUs: 4, MemoryGiB: 8, DiskGiB: 50, Arch: "aarch64", Agent: "codex"}
	if err := f.Validate(); err == nil || !strings.Contains(err.Error(), "agent") {
		t.Errorf("expected agent validation error in v1, got %v", err)
	}
	f = Form{CPUs: 4, MemoryGiB: 8, DiskGiB: 50, Arch: "aarch64", Agent: "claude"}
	if err := f.Validate(); err != nil {
		t.Errorf("expected ok, got %v", err)
	}
}

func TestForm_Apply_ProducesPerVM(t *testing.T) {
	f := Form{
		CPUs: 8, MemoryGiB: 16, DiskGiB: 200, Arch: "aarch64", Agent: "claude",
		ExtraMounts: []string{"/Users/me/data", "/Users/me/notes"},
	}
	v := f.Apply()
	if v.CPUs != 8 || v.MemoryGiB != 16 || v.DiskGiB != 200 || v.Agent != "claude" {
		t.Errorf("apply lost fields: %+v", v)
	}
	if len(v.Mounts) != 2 {
		t.Errorf("mounts not generated: %+v", v.Mounts)
	}
	for i, want := range []string{"/Users/me/data", "/Users/me/notes"} {
		if v.Mounts[i].HostPath != want {
			t.Errorf("mount %d host = %q, want %q", i, v.Mounts[i].HostPath, want)
		}
		if v.Mounts[i].VMPath != want {
			t.Errorf("mount %d vm path defaults to host path; got %q", i, v.Mounts[i].VMPath)
		}
		if !v.Mounts[i].Writable {
			t.Errorf("mount %d expected writable=true by default", i)
		}
	}
}
