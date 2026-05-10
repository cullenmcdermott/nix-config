package lima

import (
	"strings"
	"testing"
)

func TestRenderProvision_BindsSubpathsAndInstallsUnit(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, must := range []string{
		"set -euo pipefail",
		`USER_HOME="/home/alice"`,
		"mkdir -p \"$USER_HOME/.claude\"",
		`mount --bind -o ro "$HOST_CLAUDE/skills"`,
		`mount --bind -o ro "$HOST_CLAUDE/CLAUDE.md"`,
		"[Service]",
		"sandbox-claude-overlay.service",
	} {
		if !strings.Contains(got, must) {
			t.Errorf("missing %q in provision script:\n%s", must, got)
		}
	}
}

func TestRenderProvision_IdempotentViaMountpointCheck(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "bob",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	// Every bind mount must be guarded by mountpoint check.
	count := strings.Count(got, "mountpoint -q")
	if count == 0 {
		t.Errorf("no mountpoint guards found in script:\n%s", got)
	}
	if count < len(subPathsForUnit) {
		t.Errorf("expected at least %d mountpoint guards, got %d", len(subPathsForUnit), count)
	}
}

func TestRenderProvision_SystemdUnitInstalled(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "carol",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "systemctl daemon-reload") {
		t.Errorf("missing systemctl daemon-reload:\n%s", got)
	}
	if !strings.Contains(got, "systemctl enable sandbox-claude-overlay.service") {
		t.Errorf("missing systemctl enable:\n%s", got)
	}
	if !strings.Contains(got, "After=local-fs.target lima-mounts.target") {
		t.Errorf("missing systemd After= directive:\n%s", got)
	}
}