package cli

import (
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
	mounts := BuildMounts("/Users/alice/proj", "/Users/alice", nil)
	for _, sub := range []string{"skills", "commands", "agents", "hooks"} {
		host := "/Users/alice/.claude/" + sub
		vm := "/var/sandbox/host-claude/" + sub
		if !containsMount(mounts, host, vm, false) {
			t.Errorf("missing RO mount for %s", sub)
		}
	}
	if !containsMount(mounts, "/Users/alice/.claude/CLAUDE.md", "/var/sandbox/host-claude/CLAUDE.md", false) {
		t.Errorf("missing CLAUDE.md mount")
	}
	if !containsMount(mounts, "/Users/alice/.claude/settings.json", "/var/sandbox/host-claude/settings.json", false) {
		t.Errorf("missing settings.json mount")
	}
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

func TestBuildMounts_AllVirtiofsInPhase5(t *testing.T) {
	mounts := BuildMounts("/Users/alice/proj", "/Users/alice", nil)
	for _, m := range mounts {
		if m.SyncMode != backend.SyncVirtiofs {
			t.Errorf("mount %+v expected virtiofs in phase 5", m)
		}
	}
	_ = reflect.DeepEqual // keep import alive for future use
}