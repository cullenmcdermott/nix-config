package lima

import (
	"strings"
	"testing"
)

func TestRenderProvision_FullStack(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		FloxVersion:         "1.12.0",
		FloxURL:             "https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb",
		FloxSHA256:          "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
		ClaudeVersion:       "2.1.138",
		ClaudeURL:           "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.138/linux-arm64/claude",
		ClaudeSHA256:        "cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe",
		AgentsMarkdown:      "## Environment\nhello\n",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, must := range []string{
		"set -euo pipefail",
		"# ── ~/.claude RO overlay ───",
		"# ── Nix ──",
		"curl -L https://nixos.org/nix/install",
		"# ── Flox ──",
		"https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb",
		"sha256sum -c",
		"# ── Claude Code ──",
		"storage.googleapis.com/claude-code-dist",
		"https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.138/linux-arm64/claude",
		"# ── AGENTS.md ──",
		"/etc/sandbox/AGENTS.md",
		"## Environment",
		"sandbox-helper.service",
		"StreamLocalBindUnlink",
	} {
		if !strings.Contains(got, must) {
			t.Errorf("missing %q in:\n%s", must, got)
		}
	}
}

func TestRenderProvision_OverlayMountsAllSubpaths(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	// Each subpath should appear as an if-block with mount --bind.
	for _, sub := range []string{"skills", "commands", "agents", "hooks", "CLAUDE.md", "settings.json"} {
		if !strings.Contains(got, "mount --bind -o ro \"$HOST_CLAUDE/"+sub+"\"") {
			t.Errorf("missing mount for %s", sub)
		}
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

func TestRenderProvision_NixGuardedByDirCheck(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{User: "bob", HostClaudeMountRoot: "/var/sandbox/host-claude"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "[ ! -d /nix ]") {
		t.Errorf("nix install not guarded by /nix directory check:\n%s", got)
	}
}

func TestRenderProvision_FloxGuardedByCommandCheck(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{User: "bob", HostClaudeMountRoot: "/var/sandbox/host-claude"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "command -v flox") {
		t.Errorf("flox install not guarded by command -v check:\n%s", got)
	}
}

func TestRenderProvision_ClaudeGuardedByCommandCheck(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{User: "bob", HostClaudeMountRoot: "/var/sandbox/host-claude"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "command -v claude") {
		t.Errorf("claude install not guarded by command -v check:\n%s", got)
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
	count := strings.Count(got, "mountpoint -q")
	if count == 0 {
		t.Errorf("no mountpoint guards found in script:\n%s", got)
	}
	if count < len(subPathsForUnit) {
		t.Errorf("expected at least %d mountpoint guards, got %d", len(subPathsForUnit), count)
	}
}

func TestRenderProvision_AgentsMarkdownSeeded(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		AgentsMarkdown:      "## Verify Before Claiming\ntruth only\n",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "## Verify Before Claiming") {
		t.Errorf("AgentsMarkdown not embedded:\n%s", got)
	}
	if !strings.Contains(got, "ln -sfn /etc/sandbox/AGENTS.md") {
		t.Errorf("AGENTS.md symlink not created:\n%s", got)
	}
}

func TestRenderProvision_SSHDSocketForwarding(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{User: "alice", HostClaudeMountRoot: "/var/sandbox/host-claude"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "StreamLocalBindUnlink") {
		t.Errorf("sshd StreamLocalBindUnlink not configured:\n%s", got)
	}
}

func TestRenderProvision_ApplyScriptUsesPrintfNotHeredoc(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{User: "alice", HostClaudeMountRoot: "/var/sandbox/host-claude"})
	if err != nil {
		t.Fatal(err)
	}
	// The apply script uses printf (not a heredoc) so the template range
	// can inline the per-subpath commands cleanly.
	if !strings.Contains(got, "printf '#!/usr/bin/env bash") {
		t.Errorf("apply script not using printf pattern:\n%s", got)
	}
	if !strings.Contains(got, "/etc/sandbox/apply-claude-overlay.sh") {
		t.Errorf("apply script path not in template:\n%s", got)
	}
}