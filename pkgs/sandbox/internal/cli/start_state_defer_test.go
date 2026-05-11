package cli

import (
	"context"
	"errors"
	"io"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/mutagen"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

// failRunner implements mutagen.Runner and fails every command.
type failRunner struct{}

func (failRunner) Output(_ context.Context, _ io.Reader, _ ...string) ([]byte, error) {
	return nil, errors.New("mutagen unreachable")
}

func (failRunner) Run(_ context.Context, _ io.Reader, _, _ io.Writer, _ ...string) error {
	return errors.New("mutagen unreachable")
}

// NEW-I-3 / C-I-4: when Mutagen setup fails during doCreate, the persisted
// state must NOT be RUNNING — otherwise the next `sandbox start` would
// short-circuit on "already running" and never retry the failed setup.
func TestDoCreate_MutagenFailureLeavesStateNonRunning(t *testing.T) {
	app := newTestApp(t)
	app.Mutagen = mutagen.New(failRunner{})

	cmd := NewRootForApp(app)
	cmd.SetArgs([]string{"start"})
	cmd.SetOut(io.Discard)
	cmd.SetErr(io.Discard)
	err := cmd.Execute()
	if err == nil {
		t.Fatal("expected error from failing mutagen, got nil")
	}

	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsDataDir, "*", "state.json"))
	if len(matches) != 1 {
		t.Fatalf("expected 1 state.json, got %d", len(matches))
	}
	got, err := state.Read(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	if got == state.StateRunning {
		t.Errorf("state must not be RUNNING when mutagen setup failed; got %s", got)
	}
	// FAILED is the expected outcome — destroy/recreate is the recovery path.
	if got != state.StateFailed {
		t.Errorf("expected FAILED after mutagen failure, got %s", got)
	}
}

// Same invariant for doStart (resume path).
func TestDoStart_MutagenFailureLeavesStateNonRunning(t *testing.T) {
	app := newTestApp(t)
	// First start with no Mutagen (succeeds), then move to STOPPED, then
	// re-start with a failing Mutagen.
	_ = runSubcommand(t, app, "start")

	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsDataDir, "*", "state.json"))
	if len(matches) != 1 {
		t.Fatalf("expected 1 state.json after first start, got %d", len(matches))
	}
	if err := state.Write(matches[0], state.StateStopped); err != nil {
		t.Fatal(err)
	}

	app.Mutagen = mutagen.New(failRunner{})
	cmd := NewRootForApp(app)
	cmd.SetArgs([]string{"start"})
	cmd.SetOut(io.Discard)
	cmd.SetErr(io.Discard)
	if err := cmd.Execute(); err == nil {
		t.Fatal("expected error from failing mutagen on resume, got nil")
	}
	got, err := state.Read(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	if got == state.StateRunning {
		t.Errorf("state must not be RUNNING when mutagen setup failed on resume; got %s", got)
	}
}

// Sanity: when mutagen is nil (default test app) and bridge is nil, doCreate
// still writes RUNNING. This guards against accidentally regressing the happy
// path while shifting the state.Write call site.
func TestDoCreate_HappyPathStillWritesRunning(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "start")
	if !strings.Contains(out, "VM running") {
		t.Errorf("expected 'VM running' message, got %q", out)
	}
	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsDataDir, "*", "state.json"))
	got, err := state.Read(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	if got != state.StateRunning {
		t.Errorf("happy path must end at RUNNING, got %s", got)
	}
}
