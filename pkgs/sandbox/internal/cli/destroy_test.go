package cli

import (
	"context"
	"os"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

func TestDestroy_RemovesStateAndConfig(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")
	out := runSubcommand(t, app, "destroy", "--force")
	_ = out

	// Backend should report Gone.
	infos, _ := app.Backend.List(context.Background())
	for _, i := range infos {
		if i.Status == backend.StatusRunning {
			t.Errorf("vm still running after destroy: %v", i)
		}
	}
	// State + config dirs gone.
	if entries, _ := os.ReadDir(app.Paths.VMsDataDir); len(entries) != 0 {
		t.Errorf("expected empty VMsDataDir, got %v", entries)
	}
	if entries, _ := os.ReadDir(app.Paths.VMsConfigDir); len(entries) != 0 {
		t.Errorf("expected empty VMsConfigDir, got %v", entries)
	}
	statusOut := runSubcommand(t, app, "status")
	if !strings.Contains(statusOut, "State: NEW") {
		t.Errorf("expected NEW after destroy, got %q", statusOut)
	}
}

func TestDestroy_RequiresForceForRunningVM(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	cmd := NewRootForApp(app)
	cmd.SetArgs([]string{"destroy"}) // no --force
	cmd.SetOut(os.Stderr)
	cmd.SetErr(os.Stderr)
	if err := cmd.Execute(); err == nil {
		t.Fatal("expected error when destroying a running VM without --force")
	}
}
