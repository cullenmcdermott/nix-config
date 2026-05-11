package cli

import (
	"bytes"
	"strings"
	"testing"
)

func TestRoot_VMFlagOverridesCwd(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "--vm=fake-id-aaaaaa", "status")
	if !strings.Contains(out, "VM ID: fake-id-aaaaaa") {
		t.Errorf("expected --vm to override; got %q", out)
	}
}

func TestRoot_VersionFlag_PrintsBuildVersion(t *testing.T) {
	app := newTestApp(t)
	cmd := NewRootForApp(app)
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs([]string{"--version"})
	if err := cmd.Execute(); err != nil {
		t.Fatalf("Execute() error: %v", err)
	}
	got := strings.TrimSpace(out.String())
	if !strings.HasPrefix(got, "sandbox ") {
		t.Fatalf("output = %q, want prefix %q", got, "sandbox ")
	}
}

func TestRoot_NoArgs_ShowsHelpAndExitsCleanly(t *testing.T) {
	app := newTestApp(t)
	cmd := NewRootForApp(app)
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs([]string{})
	if err := cmd.Execute(); err != nil {
		t.Fatalf("Execute() error: %v", err)
	}
	if !strings.Contains(out.String(), "Usage:") {
		t.Fatalf("output missing usage banner: %q", out.String())
	}
}