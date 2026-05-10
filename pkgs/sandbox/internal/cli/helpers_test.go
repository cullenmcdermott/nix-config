package cli

import (
	"bytes"
	"os"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
)

func newTestApp(t *testing.T) *App {
	t.Helper()
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
	p, err := paths.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	if err := p.EnsureDirs(); err != nil {
		t.Fatal(err)
	}
	return &App{Paths: p, Backend: backend.NewFake()}
}

func runSubcommand(t *testing.T, app *App, args ...string) string {
	t.Helper()
	cmd := NewRootForApp(app)
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs(args)
	if err := cmd.Execute(); err != nil {
		t.Fatalf("execute %v: %v\n%s", args, err, out.String())
	}
	return out.String()
}
