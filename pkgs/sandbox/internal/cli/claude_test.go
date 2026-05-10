package cli

import (
	"strings"
	"testing"
)

func TestClaude_AutoStartsThenSSHs(t *testing.T) {
	app := newTestApp(t)
	var sshHost string
	var sshForwards, sshArgs []string
	app.sshExec = func(cfg, host string, forwards, args []string) error {
		sshHost = host
		sshForwards = forwards
		sshArgs = args
		return nil
	}
	_ = runSubcommand(t, app, "claude", "--", "-p", "hi")
	if sshHost == "" {
		t.Fatal("ssh was not invoked")
	}
	joined := strings.Join(sshArgs, " ")
	if !strings.Contains(joined, "claude") {
		t.Errorf("expected ssh args to invoke claude, got %v", sshArgs)
	}
	// Bridge forward must be present.
	fwd := strings.Join(sshForwards, " ")
	if !strings.Contains(fwd, "/run/sandbox-bridge.sock") {
		t.Errorf("missing bridge forward in ssh forwards: %v", sshForwards)
	}
}
