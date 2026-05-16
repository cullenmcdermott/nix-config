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

	// SSH args must be a single element so SSH doesn't word-split.
	if len(sshArgs) != 1 {
		t.Fatalf("expected 1 ssh arg (single command string), got %d: %v", len(sshArgs), sshArgs)
	}
	cmd := sshArgs[0]

	// Profile must be sourced for PATH setup.
	if !strings.Contains(cmd, ". /etc/profile") {
		t.Errorf("expected profile sourcing in ssh command, got: %s", cmd)
	}
	// --dangerously-skip-permissions must be present.
	if !strings.Contains(cmd, "--dangerously-skip-permissions") {
		t.Errorf("expected --dangerously-skip-permissions in ssh command, got: %s", cmd)
	}
	// Flox activation guard must be present.
	if !strings.Contains(cmd, "flox activate") {
		t.Errorf("expected flox activation in ssh command, got: %s", cmd)
	}
	// User args must be passed through.
	if !strings.Contains(cmd, "'-p'") {
		t.Errorf("expected user arg -p in ssh command, got: %s", cmd)
	}
	// Bridge forward must be present.
	fwd := strings.Join(sshForwards, " ")
	if !strings.Contains(fwd, "/run/sandbox/bridge.sock") {
		t.Errorf("missing bridge forward in ssh forwards: %v", sshForwards)
	}
}

func TestBuildClaudeSSHCmd(t *testing.T) {
	cmd := buildClaudeSSHCmd("/Users/test/project", []string{"-p", "hello world"})

	// Must source profile first.
	if !strings.HasPrefix(cmd, ". /etc/profile && ") {
		t.Errorf("command should start with profile sourcing, got: %s", cmd)
	}
	// Must cd to the directory.
	if !strings.Contains(cmd, "cd '/Users/test/project'") {
		t.Errorf("missing cd to project dir, got: %s", cmd)
	}
	// Must have flox activation.
	if !strings.Contains(cmd, `if [ -d .flox ]; then eval "$(flox activate)"; fi`) {
		t.Errorf("missing flox activation, got: %s", cmd)
	}
	// Must exec claude with permissions flag.
	if !strings.Contains(cmd, "exec claude --dangerously-skip-permissions") {
		t.Errorf("missing exec claude with permissions flag, got: %s", cmd)
	}
	// Args must be shell-quoted.
	if !strings.Contains(cmd, "'hello world'") {
		t.Errorf("expected quoted arg 'hello world', got: %s", cmd)
	}
}
