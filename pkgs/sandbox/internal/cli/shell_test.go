package cli

import (
	"strings"
	"testing"
)

func TestShell_ErrorsWhenVMNotRunning(t *testing.T) {
	app := newTestApp(t)
	cmd := NewRootForApp(app)
	cmd.SetArgs([]string{"shell"})
	if err := cmd.Execute(); err == nil {
		t.Fatal("expected error when shelling into a NEW VM")
	}
}

func TestShell_InvokesSSHWhenRunning(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")

	var calledConfig, calledHost string
	var calledArgs []string
	app.sshExec = func(cfg, host string, args []string) error {
		calledConfig = cfg
		calledHost = host
		calledArgs = args
		return nil
	}
	_ = runSubcommand(t, app, "shell")
	if calledConfig == "" {
		t.Errorf("ssh config empty")
	}
	if !strings.HasPrefix(calledHost, "lima-sandbox-") && !strings.HasPrefix(calledHost, "fake-") {
		t.Errorf("host = %q", calledHost)
	}
	_ = calledArgs
}
