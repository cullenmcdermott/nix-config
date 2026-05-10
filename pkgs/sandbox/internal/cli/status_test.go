package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// helper: run sandbox status with HOME pointed at a tempdir
func runStatusInTempHome(t *testing.T, args []string) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")

	// Make cwd a tempdir without git so vmid falls back to cwd.
	wd := t.TempDir()
	cwd, _ := os.Getwd()
	t.Cleanup(func() { _ = os.Chdir(cwd) })
	if err := os.Chdir(wd); err != nil {
		t.Fatal(err)
	}

	cmd := NewRoot()
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs(append([]string{"status"}, args...))
	if err := cmd.Execute(); err != nil {
		t.Fatalf("Execute: %v", err)
	}
	return out.String()
}

func TestStatus_NewWhenNoState(t *testing.T) {
	out := runStatusInTempHome(t, nil)
	if !strings.Contains(out, "State: NEW") {
		t.Errorf("expected State: NEW; got %q", out)
	}
	if !strings.Contains(out, "VM ID:") {
		t.Errorf("expected a VM ID line; got %q", out)
	}
}

func TestStatus_ReadsPersistedState(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("XDG_DATA_HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	wd := t.TempDir()
	cwd, _ := os.Getwd()
	t.Cleanup(func() { _ = os.Chdir(cwd) })
	if err := os.Chdir(wd); err != nil {
		t.Fatal(err)
	}

	// Pre-populate a STOPPED state for the vm-id of this cwd.
	// We don't compute the id ourselves here — we let the command run once
	// to discover the dir, then write the file, then run again.
	cmd := NewRoot()
	var first bytes.Buffer
	cmd.SetOut(&first)
	cmd.SetErr(&first)
	cmd.SetArgs([]string{"status"})
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	// VM ID is on a "VM ID: <id>" line — extract the id.
	var id string
	for _, line := range strings.Split(first.String(), "\n") {
		if strings.HasPrefix(line, "VM ID:") {
			id = strings.TrimSpace(strings.TrimPrefix(line, "VM ID:"))
		}
	}
	if id == "" {
		t.Fatalf("could not parse VM ID from %q", first.String())
	}

	statePath := filepath.Join(home, ".local", "share", "sandbox", "vms", id, "state.json")
	if err := os.MkdirAll(filepath.Dir(statePath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(statePath, []byte(`{"state":"STOPPED"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	cmd2 := NewRoot()
	var second bytes.Buffer
	cmd2.SetOut(&second)
	cmd2.SetErr(&second)
	cmd2.SetArgs([]string{"status"})
	if err := cmd2.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(second.String(), "State: STOPPED") {
		t.Errorf("expected STOPPED, got %q", second.String())
	}
}
