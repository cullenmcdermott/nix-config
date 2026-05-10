package cli

import (
	"strings"
	"testing"
)

func TestVMList_ShowsKnownVMs(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")
	out := runSubcommand(t, app, "vm", "list")
	if !strings.Contains(out, "RUNNING") {
		t.Errorf("expected RUNNING in vm list, got %q", out)
	}
}

func TestVMList_EmptyByDefault(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "vm", "list")
	if !strings.Contains(strings.ToLower(out), "no vms") {
		t.Errorf("expected empty message, got %q", out)
	}
}
