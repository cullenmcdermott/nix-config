package cli

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

func TestStart_FromNew_CreatesAndPersistsRunning(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "start")
	if !strings.Contains(out, "creating") && !strings.Contains(out, "Created") {
		t.Logf("output: %q", out) // not strict — just for debugging
	}

	// Persisted state should be RUNNING.
	statusOut := runSubcommand(t, app, "status")
	if !strings.Contains(statusOut, "State: RUNNING") {
		t.Errorf("expected RUNNING; got %q", statusOut)
	}

	// File should exist.
	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsDataDir, "*", "state.json"))
	if len(matches) != 1 {
		t.Fatalf("expected 1 state.json, got %d", len(matches))
	}
	got, err := state.Read(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	if got != state.StateRunning {
		t.Errorf("on-disk state = %s, want RUNNING", got)
	}
}

func TestStart_FromRunning_IsNoop(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")
	out := runSubcommand(t, app, "start")
	if !strings.Contains(strings.ToLower(out), "already running") {
		t.Errorf("expected already-running msg, got %q", out)
	}
}

func TestStart_FromStopped_StartsExisting(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	// Move backend + state to Stopped.
	infos, _ := app.Backend.List(context.Background())
	if len(infos) != 1 {
		t.Fatalf("expected 1 vm, got %d", len(infos))
	}
	_ = app.Backend.Stop(context.Background(), infos[0].ID)
	statePath := filepath.Join(app.Paths.VMsDataDir, string(infos[0].ID), "state.json")
	_ = state.Write(statePath, state.StateStopped)

	_ = runSubcommand(t, app, "start")
	statusOut := runSubcommand(t, app, "status")
	if !strings.Contains(statusOut, "State: RUNNING") {
		t.Errorf("expected RUNNING after start-from-stopped, got %q", statusOut)
	}
}
