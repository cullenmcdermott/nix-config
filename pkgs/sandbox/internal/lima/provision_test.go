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
		"# ── CLAUDE.md",
		"/etc/sandbox/CLAUDE.md",
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
		ClaudeSubpaths:      []string{"skills", "commands", "agents", "hooks"},
	})
	if err != nil {
		t.Fatal(err)
	}
	// Each subpath should appear as an if-block with mount --bind.
	for _, sub := range []string{"skills", "commands", "agents", "hooks"} {
		if !strings.Contains(got, "mount --bind -o ro \"$HOST_CLAUDE/"+sub+"\"") {
			t.Errorf("missing mount for %s", sub)
		}
	}
	// CLAUDE.md and settings.json are no longer mounted (Lima expects directories).
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
		ClaudeSubpaths:      []string{"skills", "commands", "agents", "hooks"},
	})
	if err != nil {
		t.Fatal(err)
	}
	count := strings.Count(got, "mountpoint -q")
	if count == 0 {
		t.Errorf("no mountpoint guards found in script:\n%s", got)
	}
	if count < 4 {
		// At least one guard per ClaudeSubpath entry × 2 (inline + overlay script).
		t.Errorf("expected at least 4 mountpoint guards, got %d", count)
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
	if !strings.Contains(got, "ln -sfn /etc/sandbox/CLAUDE.md") {
		t.Errorf("CLAUDE.md symlink not created:\n%s", got)
	}
	// The heredoc must redirect to /etc/sandbox/CLAUDE.md so the symlink
	// target exists. Prior bug: heredoc dumped to stdout, leaving a dangling
	// symlink (NEW-I-1).
	if !strings.Contains(got, "cat > /etc/sandbox/CLAUDE.md <<'CLAUDE_MD_EOF'") {
		t.Errorf("CLAUDE.md heredoc must redirect to file, not stdout:\n%s", got)
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

func TestRenderProvision_RsyncSeedFromWarmTemplate(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{User: "alice", HostClaudeMountRoot: "/var/sandbox/host-claude"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "/var/sandbox/warm-nix/store") {
		t.Errorf("warm template mount path not in script:\n%s", got)
	}
	if !strings.Contains(got, "rsync") {
		t.Errorf("rsync not in script:\n%s", got)
	}
	if !strings.Contains(got, "--ignore-existing") {
		t.Errorf("rsync --ignore-existing not in script:\n%s", got)
	}
	if !strings.Contains(got, "# ── Seed /nix/store from warm template ─") {
		t.Errorf("warm seed comment not in script:\n%s", got)
	}
}
func TestRenderProvision_OmpBinaryInstall(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		OmpVersion:          "14.9.3",
		OmpURL:              "https://github.com/can1357/oh-my-pi/releases/download/v14.9.3/omp-linux-arm64",
		OmpSHA256:           "d8a0f46a3aa638ddaa681507e8b310f99791855413b48386244e850a6c001549",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, needle := range []string{
		"# ── omp",
		"command -v omp",
		"omp-linux-arm64",
		"sha256sum -c",
		"/usr/local/bin/omp",
	} {
		if !strings.Contains(got, needle) {
			t.Errorf("missing %q in provision script", needle)
		}
	}
}

func TestRenderProvision_OmpConfigSetup(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		HostOmpMountRoot:    "/var/sandbox/host-omp",
		OmpSubpaths:         []string{"skills", "prompts", "extensions", "themes"},
		OmpConfigYAML:       "defaultModel: claude-sonnet-4-6\nsessionDir: /home/alice/.local/state/omp/sessions\n",
		OmpAgentsMarkdown:   "## Sandbox Environment\ntest content\n",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, needle := range []string{
		"$USER_HOME/.config/omp/agent",
		"config.yml",
		"AGENTS.md",
		"PI_CODING_AGENT_DIR",
		"PI_CONFIG_DIR",
		"omp-env.sh",
	} {
		if !strings.Contains(got, needle) {
			t.Errorf("missing %q in provision script", needle)
		}
	}
}

func TestRenderProvision_OmpBindMounts(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:             "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		HostOmpMountRoot: "/var/sandbox/host-omp",
		OmpSubpaths:      []string{"skills", "prompts", "extensions", "themes"},
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, sub := range []string{"skills", "prompts", "extensions", "themes"} {
		needle := `mount --bind -o ro "$HOST_OMP/` + sub + `"`
		if !strings.Contains(got, needle) {
			t.Errorf("missing omp bind mount for %s", sub)
		}
	}
}

func TestRenderProvision_OmpOverlayReapply(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:             "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		HostOmpMountRoot: "/var/sandbox/host-omp",
		OmpSubpaths:      []string{"skills", "prompts"},
	})
	if err != nil {
		t.Fatal(err)
	}
	// The overlay re-apply script must include omp mount re-application.
	if !strings.Contains(got, `HOST_OMP="`) {
		t.Errorf("overlay script missing HOST_OMP variable")
	}
}

func TestRenderProvision_OmpEnvVars(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, `PI_CODING_AGENT_DIR`) {
		t.Errorf("missing PI_CODING_AGENT_DIR in provision script")
	}
	if !strings.Contains(got, `PI_CONFIG_DIR`) {
		t.Errorf("missing PI_CONFIG_DIR in provision script")
	}
}
