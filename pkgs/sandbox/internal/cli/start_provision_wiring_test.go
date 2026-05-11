package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

// Ensure doCreate passes ClaudeSubpaths through to RenderProvision (NEW-C-1).
// The prior bug exported ClaudeSubpaths and added a ProvisionConfig field, but
// the call site never set it — so the in-VM RO overlay was empty.
func TestDoCreate_PassesClaudeSubpathsToProvision(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	fake, ok := app.Backend.(*backend.Fake)
	if !ok {
		t.Fatalf("expected *backend.Fake, got %T", app.Backend)
	}
	script := fake.LastSpec.Provision.Script
	if script == "" {
		t.Fatal("provision script is empty — Create was not called with a script")
	}
	for _, sub := range ClaudeSubpaths {
		needle := `mount --bind -o ro "$HOST_CLAUDE/` + sub + `"`
		if !strings.Contains(script, needle) {
			t.Errorf("provision script missing bind-mount for %q\nfull script:\n%s", sub, script)
		}
	}
}

func TestDoCreate_PassesOmpSubpathsToProvision(t *testing.T) {
	app := newTestApp(t)

	// Create omp host directories so BuildMounts includes them.
	for _, sub := range OmpSubpaths {
		dir := filepath.Join(app.Paths.Home, ".config", "omp", "agent", sub)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	_ = runSubcommand(t, app, "start")

	fake, ok := app.Backend.(*backend.Fake)
	if !ok {
		t.Fatalf("expected *backend.Fake, got %T", app.Backend)
	}
	script := fake.LastSpec.Provision.Script
	if script == "" {
		t.Fatal("provision script is empty")
	}
	for _, sub := range OmpSubpaths {
		needle := `mount --bind -o ro "$HOST_OMP/` + sub + `"`
		if !strings.Contains(script, needle) {
			t.Errorf("provision script missing omp bind-mount for %q", sub)
		}
	}
}

func TestDoCreate_PassesOmpVersionToProvision(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	fake, ok := app.Backend.(*backend.Fake)
	if !ok {
		t.Fatalf("expected *backend.Fake, got %T", app.Backend)
	}
	script := fake.LastSpec.Provision.Script
	if !strings.Contains(script, "omp-linux-arm64") {
		t.Errorf("provision script missing omp download URL")
	}
}