package cli

import (
	"strings"
	"testing"
)

func TestStop_FromRunning_TransitionsToStopped(t *testing.T) {
	app := newTestApp(t)
	_ = runSubcommand(t, app, "start")
	_ = runSubcommand(t, app, "stop")
	out := runSubcommand(t, app, "status")
	if !strings.Contains(out, "State: STOPPED") {
		t.Errorf("expected STOPPED, got %q", out)
	}
}

func TestStop_FromNew_IsNoop(t *testing.T) {
	app := newTestApp(t)
	out := runSubcommand(t, app, "stop")
	if !strings.Contains(strings.ToLower(out), "not running") &&
		!strings.Contains(strings.ToLower(out), "no vm") {
		t.Errorf("expected friendly message; got %q", out)
	}
}
