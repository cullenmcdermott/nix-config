package cli

import (
	"strings"
	"testing"
)

func TestOmp_AutoStartsThenSSHs(t *testing.T) {
	app := newTestApp(t)
	var sshHost string
	var sshForwards, sshArgs []string
	app.sshExec = func(cfg, host string, forwards, args []string) error {
		sshHost = host
		sshForwards = forwards
		sshArgs = args
		return nil
	}
	_ = runSubcommand(t, app, "omp", "--", "-p", "hi")
	if sshHost == "" {
		t.Fatal("ssh was not invoked")
	}

	// SSH args must be a single element.
	if len(sshArgs) != 1 {
		t.Fatalf("expected 1 ssh arg, got %d: %v", len(sshArgs), sshArgs)
	}
	cmd := sshArgs[0]

	// Profile must be sourced.
	if !strings.Contains(cmd, ". /etc/profile") {
		t.Errorf("expected profile sourcing, got: %s", cmd)
	}
	// Must NOT have --dangerously-skip-permissions (omp doesn't have this flag).
	if strings.Contains(cmd, "--dangerously-skip-permissions") {
		t.Errorf("omp command should not have --dangerously-skip-permissions, got: %s", cmd)
	}
	// Must exec omp.
	if !strings.Contains(cmd, "exec omp") {
		t.Errorf("expected exec omp in command, got: %s", cmd)
	}
	// Flox activation guard must be present.
	if !strings.Contains(cmd, "flox activate") {
		t.Errorf("expected flox activation, got: %s", cmd)
	}
	// User args must be passed through.
	if !strings.Contains(cmd, "'-p'") {
		t.Errorf("expected user arg -p, got: %s", cmd)
	}
	// Bridge forward must be present.
	fwd := strings.Join(sshForwards, " ")
	if !strings.Contains(fwd, "/run/sandbox/bridge.sock") {
		t.Errorf("missing bridge forward: %v", sshForwards)
	}
}

func TestBuildOmpSSHCmd(t *testing.T) {
	cmd := buildOmpSSHCmd("/Users/test/project", []string{"-p", "hello world"})

	if !strings.HasPrefix(cmd, ". /etc/profile && ") {
		t.Errorf("should start with profile sourcing, got: %s", cmd)
	}
	if !strings.Contains(cmd, "cd '/Users/test/project'") {
		t.Errorf("missing cd to project dir, got: %s", cmd)
	}
	if !strings.Contains(cmd, `if [ -d .flox ]; then eval "$(flox activate)"; fi`) {
		t.Errorf("missing flox activation, got: %s", cmd)
	}
	if !strings.Contains(cmd, "exec omp") {
		t.Errorf("missing exec omp, got: %s", cmd)
	}
	if strings.Contains(cmd, "--dangerously-skip-permissions") {
		t.Errorf("should not have --dangerously-skip-permissions, got: %s", cmd)
	}
	if !strings.Contains(cmd, "'hello world'") {
		t.Errorf("expected quoted arg, got: %s", cmd)
	}
}
