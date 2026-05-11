package cli

import (
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
