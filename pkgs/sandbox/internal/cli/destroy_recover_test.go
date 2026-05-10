package cli

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

func TestDestroy_FailedRequiresRecoverFlag(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsDataDir, "*", "state.json"))
	if err := state.WriteRecord(matches[0], state.Record{State: state.StateDestroyFailed, LastFailedStep: "bridge-stop"}); err != nil {
		t.Fatal(err)
	}

	cmd := NewRootForApp(app)
	cmd.SetArgs([]string{"destroy"})
	cmd.SetOut(os.Stderr)
	cmd.SetErr(os.Stderr)
	err := cmd.Execute()
	if err == nil || !strings.Contains(err.Error(), "DESTROY_FAILED") {
		t.Fatalf("expected DESTROY_FAILED error, got %v", err)
	}

	_ = errors.New // silence
}

func TestDestroy_RecoverSucceeds(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsDataDir, "*", "state.json"))
	_ = state.WriteRecord(matches[0], state.Record{State: state.StateDestroyFailed, LastFailedStep: "remove-host-state"})

	out := runSubcommand(t, app, "destroy", "--recover", "--force")
	if !strings.Contains(out, "destroyed") {
		t.Errorf("expected success, got %q", out)
	}
}
