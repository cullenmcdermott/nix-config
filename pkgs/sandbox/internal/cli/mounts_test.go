package cli

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

func TestBuildMounts_IncludesProjectAtSamePath(t *testing.T) {
	mounts := BuildMounts("/Users/alice/proj", "/Users/alice", nil)
	if !containsMount(mounts, "/Users/alice/proj", "/Users/alice/proj", true) {
		t.Errorf("project mount missing at same path: %+v", mounts)
	}
}

func TestBuildMounts_ROBindsAllClaudeSubpaths(t *testing.T) {
	home := t.TempDir()
	for _, sub := range ClaudeSubpaths {
		if err := os.MkdirAll(filepath.Join(home, ".claude", sub), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	mounts := BuildMounts("/Users/alice/proj", home, nil)
	for _, sub := range []string{"skills", "commands", "agents", "hooks"} {
		host := filepath.Join(home, ".claude", sub)
		vm := filepath.Join(HostClaudeMountRoot, sub)
		if !containsMount(mounts, host, vm, false) {
			t.Errorf("missing RO mount for %s", sub)
		}
	}
	// CLAUDE.md and settings.json are no longer virtiofs-mounted (Lima
	// expects directories; files are undefined). They may be copied by the
	// provision script if needed. No mount expected here.
}

func TestBuildMounts_AddsExtraMountsWritable(t *testing.T) {
	extra := []config.Mount{
		{HostPath: "/Users/alice/data", VMPath: "/Users/alice/data", Writable: true},
		{HostPath: "/Users/alice/notes", VMPath: "/notes-in-vm", Writable: false},
	}
	mounts := BuildMounts("/Users/alice/proj", "/Users/alice", extra)
	if !containsMount(mounts, "/Users/alice/data", "/Users/alice/data", true) {
		t.Errorf("first extra mount missing")
	}
	if !containsMount(mounts, "/Users/alice/notes", "/notes-in-vm", false) {
		t.Errorf("second extra mount missing")
	}
}

func TestBuildMounts_DedupesByVMPath(t *testing.T) {
	extra := []config.Mount{
		// Conflicts with /Users/alice/proj, declared first by project mount —
		// the user's later override wins.
		{HostPath: "/some/other/path", VMPath: "/Users/alice/proj", Writable: false},
	}
	mounts := BuildMounts("/Users/alice/proj", "/Users/alice", extra)
	count := 0
	for _, m := range mounts {
		if m.VMPath == "/Users/alice/proj" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("expected 1 mount at /Users/alice/proj, got %d (%+v)", count, mounts)
	}
	if !containsMount(mounts, "/some/other/path", "/Users/alice/proj", false) {
		t.Errorf("user override did not win")
	}
}

func containsMount(ms []backend.Mount, host, vm string, writable bool) bool {
	for _, m := range ms {
		if m.HostPath == host && m.VMPath == vm && m.Writable == writable {
			return true
		}
	}
	return false
}

func TestBuildMounts_ProjectIsMutagenExtraROBindsAreVirtiofs(t *testing.T) {
	mounts := BuildMounts("/Users/alice/proj", "/Users/alice", nil)
	for _, m := range mounts {
		if m.HostPath == "/Users/alice/proj" {
			if m.SyncMode != backend.SyncMutagen {
				t.Errorf("project mount expected mutagen, got %s", m.SyncMode)
			}
		} else {
			if m.SyncMode != backend.SyncVirtiofs {
				t.Errorf("RO claude subpath mount %+v expected virtiofs, got %s", m, m.SyncMode)
			}
		}
	}
	_ = reflect.DeepEqual // keep import alive for future use
}

func TestBuildMountsWithWarm_AddsWarmMountWhenProvided(t *testing.T) {
	mounts := BuildMountsWithWarm("/Users/alice/proj", "/Users/alice", nil, "/Users/alice/.local/share/sandbox/nix-warm")
	if !containsMount(mounts, "/Users/alice/.local/share/sandbox/nix-warm", WarmNixVMPath, false) {
		t.Errorf("warm mount missing: %+v", mounts)
	}
	// Verify warm mount is virtiofs.
	for _, m := range mounts {
		if m.VMPath == WarmNixVMPath {
			if m.SyncMode != backend.SyncVirtiofs {
				t.Errorf("warm mount expected virtiofs, got %s", m.SyncMode)
			}
			if m.Writable {
				t.Errorf("warm mount expected read-only, got writable")
			}
		}
	}
}

func TestBuildMountsWithWarm_NoWarmMountWhenEmpty(t *testing.T) {
	mounts := BuildMountsWithWarm("/Users/alice/proj", "/Users/alice", nil, "")
	for _, m := range mounts {
		if m.VMPath == WarmNixVMPath {
			t.Errorf("warm mount should not appear with empty warmHostDir: %+v", m)
		}
	}
}

func TestBuildMountsWithWarm_DedupesWithExtras(t *testing.T) {
	// If an extra mount already maps WarmNixVMPath, user override wins.
	mounts := BuildMountsWithWarm("/Users/alice/proj", "/Users/alice", []config.Mount{
		{HostPath: "/custom/warm", VMPath: WarmNixVMPath, Writable: true},
	}, "/Users/alice/.local/share/sandbox/nix-warm")
	found := false
	for _, m := range mounts {
		if m.VMPath == WarmNixVMPath {
			found = true
			if m.HostPath != "/custom/warm" {
				t.Errorf("expected user override to win, got host=%q", m.HostPath)
			}
			if !m.Writable {
				t.Errorf("expected writable override")
			}
		}
	}
	if !found {
		t.Errorf("warm mount missing entirely")
	}
}
