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
		ClaudeGCSBase:       "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
		ClaudeChannel:       "latest",
		ClaudePlatform:      "linux-arm64",
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
		`CLAUDE_BASE="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"`,
		"$CLAUDE_BASE/latest",
		"manifest.json",
		"linux-arm64/claude",
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

func TestRenderProvision_ClaudeTracksChannel(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "bob",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		ClaudeGCSBase:       "https://example.test/releases",
		ClaudeChannel:       "latest",
		ClaudePlatform:      "linux-arm64",
	})
	if err != nil {
		t.Fatal(err)
	}
	// Version is resolved from the channel at provision time (every boot) and
	// tracked via a stamp file so unchanged versions skip the download.
	if !strings.Contains(got, `WANT_CLAUDE=$(curl -fsSL --max-time 30 "$CLAUDE_BASE/latest"`) {
		t.Errorf("channel version resolution not in script:\n%s", got)
	}
	if !strings.Contains(got, "/etc/sandbox/claude-version") {
		t.Errorf("claude version stamp file not in script:\n%s", got)
	}
	// Downloads must be verified against the release manifest's checksum.
	if !strings.Contains(got, "manifest.json") || !strings.Contains(got, "sha256sum -c") {
		t.Errorf("manifest checksum verification not in script:\n%s", got)
	}
	if !strings.Contains(got, `["platforms"]["linux-arm64"]["checksum"]`) {
		t.Errorf("platform checksum lookup not in script:\n%s", got)
	}
	// When the wrapper has already renamed the real binary, the new binary
	// must land at claude.real, not clobber the wrapper at /usr/local/bin/claude.
	if !strings.Contains(got, `[ -x /usr/local/bin/claude.real ] && dest=/usr/local/bin/claude.real`) {
		t.Errorf("claude install does not target claude.real on wrapped VMs:\n%s", got)
	}
	// A failed update must not break boot when claude is already installed,
	// but a failed first install must fail the provision.
	if !strings.Contains(got, "warning: claude $WANT_CLAUDE install failed") {
		t.Errorf("fail-open update path not in script:\n%s", got)
	}
	if !strings.Contains(got, "error: claude install failed and no existing install present") {
		t.Errorf("fail-closed first-install path not in script:\n%s", got)
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

func TestRenderProvision_NixCacheSubstituter(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		NixCachePublicKey:   "sandbox-cache-1:AbCdEf0123==",
		NixCacheVMPath:      "/var/sandbox/nix-cache",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, needle := range []string{
		"# ── Shared Nix binary cache",
		`grep -qs "file:///var/sandbox/nix-cache" /etc/nix/nix.conf`,
		"extra-substituters = file:///var/sandbox/nix-cache",
		"extra-trusted-public-keys = sandbox-cache-1:AbCdEf0123==",
		"systemctl restart nix-daemon",
	} {
		if !strings.Contains(got, needle) {
			t.Errorf("missing %q in:\n%s", needle, got)
		}
	}
}

func TestRenderProvision_NixCacheSubstituter_OmittedWhenKeyEmpty(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	// With no NixCachePublicKey, the whole block (including the comment) must
	// not appear.
	if strings.Contains(got, "extra-substituters = file://") {
		t.Errorf("substituter line leaked into script with no public key:\n%s", got)
	}
	if strings.Contains(got, "extra-trusted-public-keys") {
		t.Errorf("trusted-public-keys line leaked into script with no public key:\n%s", got)
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
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		HostOmpMountRoot:    "/var/sandbox/host-omp",
		OmpSubpaths:         []string{"skills", "prompts", "extensions", "themes"},
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
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		HostOmpMountRoot:    "/var/sandbox/host-omp",
		OmpSubpaths:         []string{"skills", "prompts"},
	})
	if err != nil {
		t.Fatal(err)
	}
	// The overlay re-apply script must include omp mount re-application.
	if !strings.Contains(got, `HOST_OMP="`) {
		t.Errorf("overlay script missing HOST_OMP variable")
	}
}

func TestRenderProvision_BridgeShimsInstalled(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	// Both shims must read from /var/sandbox/bin and install under
	// /usr/local/bin with the destination names that other tools (op,
	// xdg-open) expect to find on PATH.
	for _, needle := range []string{
		"/var/sandbox/bin/sandbox-op",
		"install -m 0755 /var/sandbox/bin/sandbox-op /usr/local/bin/op",
		"/var/sandbox/bin/sandbox-xdg-open",
		"install -m 0755 /var/sandbox/bin/sandbox-xdg-open /usr/local/bin/xdg-open",
	} {
		if !strings.Contains(got, needle) {
			t.Errorf("missing %q in provision script", needle)
		}
	}
}

func TestRenderProvision_PersistsCredentials(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
		CredentialsVMPath:   "/var/sandbox/credentials",
	})
	if err != nil {
		t.Fatal(err)
	}
	for _, needle := range []string{
		"# ── Persistent LLM credentials",
		`CRED_ROOT="/var/sandbox/credentials"`,
		`mountpoint -q "$CRED_ROOT"`,
		`ln -sfn "$CRED_ROOT/claude/.credentials.json" "$USER_HOME/.claude/.credentials.json"`,
		`ln -sfn "$CRED_ROOT/codex/auth.json" "$USER_HOME/.codex/auth.json"`,
	} {
		if !strings.Contains(got, needle) {
			t.Errorf("missing %q in:\n%s", needle, got)
		}
	}
}

func TestRenderProvision_CredentialsOmittedWhenUnset(t *testing.T) {
	got, err := RenderProvision(ProvisionConfig{
		User:                "alice",
		HostClaudeMountRoot: "/var/sandbox/host-claude",
	})
	if err != nil {
		t.Fatal(err)
	}
	// The guarded body (not the section comment) must be absent without a path.
	if strings.Contains(got, `CRED_ROOT=`) {
		t.Errorf("credentials wiring leaked into script with no CredentialsVMPath:\n%s", got)
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

func TestRenderProvision_QuotesProjectPathAgainstShellInjection(t *testing.T) {
	// A project directory whose name contains shell metacharacters must not be
	// evaluated when the script runs as root in the VM.
	got, err := RenderProvision(ProvisionConfig{
		User:        "alice",
		ProjectPath: `/Users/alice/repo$(touch /pwned)`,
	})
	if err != nil {
		t.Fatal(err)
	}
	// The dangerous substring must appear only inside single quotes, never as a
	// bare command substitution.
	if strings.Contains(got, `"/Users/alice/repo$(touch /pwned)"`) {
		t.Fatalf("project path interpolated unquoted (command injection):\n%s", got)
	}
	if !strings.Contains(got, `install -d -o alice -g alice '/Users/alice/repo$(touch /pwned)'`) {
		t.Fatalf("project path not single-quoted:\n%s", got)
	}
}

func TestShellQuote(t *testing.T) {
	cases := map[string]string{
		`/plain/path`: `'/plain/path'`,
		`a$(b)`:       `'a$(b)'`,
		"a`b`":        "'a`b`'",
		`it's`:        `'it'\''s'`,
	}
	for in, want := range cases {
		if got := shellQuote(in); got != want {
			t.Errorf("shellQuote(%q) = %q, want %q", in, got, want)
		}
	}
}
