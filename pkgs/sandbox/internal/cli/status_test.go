package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestStatus_NewWhenNoState(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "status")
	if !strings.Contains(out, "State: NEW") {
		t.Errorf("expected State: NEW; got %q", out)
	}
	if !strings.Contains(out, "VM ID:") {
		t.Errorf("expected a VM ID line; got %q", out)
	}
}

func TestStatus_ReadsPersistedState(t *testing.T) {
	app := newTestApp(t)

	// First run: discover the VM ID for the test cwd.
	first := runSubcommand(t, app, "status")
	var id string
	for _, line := range strings.Split(first, "\n") {
		if strings.HasPrefix(line, "VM ID:") {
			id = strings.TrimSpace(strings.TrimPrefix(line, "VM ID:"))
		}
	}
	if id == "" {
		t.Fatalf("could not parse VM ID from %q", first)
	}

	statePath := filepath.Join(app.Paths.VMsDataDir, id, "state.json")
	if err := os.MkdirAll(filepath.Dir(statePath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(statePath, []byte(`{"state":"STOPPED"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	second := runSubcommand(t, app, "status")
	if !strings.Contains(second, "State: STOPPED") {
		t.Errorf("expected STOPPED, got %q", second)
	}
}
