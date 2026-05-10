package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func TestStart_WizardFires_OnFirstRun(t *testing.T) {
	app := newTestApp(t)
	called := 0
	app.Wizard = func(g config.Global) (config.PerVM, error) {
		called++
		return config.PerVM{CPUs: 6, MemoryGiB: 12, DiskGiB: 75, Arch: "aarch64", Agent: "claude"}, nil
	}
	// Force the "TTY" check to allow wizard for the test.
	t.Setenv("SANDBOX_FORCE_WIZARD", "1")

	_ = runSubcommand(t, app, "start")
	if called != 1 {
		t.Fatalf("wizard called %d times, want 1", called)
	}

	// Per-VM config persisted with wizard values.
	matches, _ := filepath.Glob(filepath.Join(app.Paths.VMsConfigDir, "*", "config.toml"))
	if len(matches) != 1 {
		t.Fatalf("got %d configs, want 1", len(matches))
	}
	v, err := config.LoadPerVM(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	if v.CPUs != 6 || v.MemoryGiB != 12 || v.DiskGiB != 75 {
		t.Errorf("persisted config = %+v", v)
	}
}

func TestStart_NoWizardFlag_BypassesWizard(t *testing.T) {
	app := newTestApp(t)
	called := 0
	app.Wizard = func(g config.Global) (config.PerVM, error) {
		called++
		return config.PerVM{}, nil
	}
	_ = runSubcommand(t, app, "start", "--no-wizard")
	if called != 0 {
		t.Errorf("wizard fired despite --no-wizard")
	}
}

func TestStart_WizardSkippedIfConfigExists(t *testing.T) {
	app := newTestApp(t)

	// Pre-create a per-VM config directly so the wizard is suppressed.
	// Previously this used "config edit" which opens a real editor via
	// $VISUAL/$EDITOR and hangs when VISUAL is set in the environment.
	id, err := vmid.ForCwd()
	if err != nil {
		t.Fatal(err)
	}
	vp := app.Paths.VM(string(id))
	if err := os.MkdirAll(vp.ConfigDir, 0o755); err != nil {
		t.Fatal(err)
	}
	v := config.PerVM{CPUs: 4, MemoryGiB: 8, DiskGiB: 50, Arch: "aarch64", Agent: "claude"}
	if err := config.SavePerVM(vp.ConfigFile, v); err != nil {
		t.Fatal(err)
	}

	called := 0
	app.Wizard = func(g config.Global) (config.PerVM, error) {
		called++
		return config.PerVM{}, nil
	}
	t.Setenv("SANDBOX_FORCE_WIZARD", "1")
	_ = runSubcommand(t, app, "start")
	if called != 0 {
		t.Errorf("wizard fired despite existing config; called %d times", called)
	}
}
