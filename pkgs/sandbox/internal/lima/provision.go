package lima

import (
	"bytes"
	"strings"
	"text/template"
)

type ProvisionConfig struct {
	User                string
	HostClaudeMountRoot string

	// Flox: .deb from downloads.flox.dev
	FloxVersion string
	FloxURL     string
	FloxSHA256  string

	// Claude Code: standalone binary from Anthropic GCS
	ClaudeVersion string
	ClaudeURL     string
	ClaudeSHA256  string

	// Seeded AGENTS.md content
	AgentsMarkdown string
}

var subPathsForUnit = []string{"skills", "commands", "agents", "hooks", "CLAUDE.md", "settings.json"}

const provisionTmpl = `#!/usr/bin/env bash
set -euo pipefail

USER_HOME="/home/{{.User}}"
HOST_CLAUDE="{{.HostClaudeMountRoot}}"

# ── ~/.claude RO overlay ──────────────────────────────────────────────────────
mkdir -p "$USER_HOME/.claude"
chown -R {{.User}}:{{.User}} "$USER_HOME/.claude"
{{range .Subs}}if [ -e "$HOST_CLAUDE/{{.}}" ]; then
  if [ -d "$HOST_CLAUDE/{{.}}" ]; then mkdir -p "$USER_HOME/.claude/{{.}}"; else [ -e "$USER_HOME/.claude/{{.}}" ] || touch "$USER_HOME/.claude/{{.}}"; fi
  mountpoint -q "$USER_HOME/.claude/{{.}}" || mount --bind -o ro "$HOST_CLAUDE/{{.}}" "$USER_HOME/.claude/{{.}}"
fi
{{end}}

install -d /etc/sandbox

# systemd unit for overlay re-apply on every boot
cat > /etc/sandbox/apply-claude-overlay.sh <<'OVERLAY'
#!/usr/bin/env bash
set -euo pipefail
USER_HOME="/home/{{.User}}"
HOST_CLAUDE="{{.HostClaudeMountRoot}}"
{{range .Subs}}if [ -e "$HOST_CLAUDE/{{.}}" ] && ! mountpoint -q "$USER_HOME/.claude/{{.}}"; then
  if [ -d "$HOST_CLAUDE/{{.}}" ]; then mkdir -p "$USER_HOME/.claude/{{.}}"; else [ -e "$USER_HOME/.claude/{{.}}" ] || touch "$USER_HOME/.claude/{{.}}"; fi
  mount --bind -o ro "$HOST_CLAUDE/{{.}}" "$USER_HOME/.claude/{{.}}"
fi
{{end}}OVERLAY
chmod +x /etc/sandbox/apply-claude-overlay.sh

cat > /etc/systemd/system/sandbox-claude-overlay.service <<'UNIT'
[Unit]
Description=Re-apply ~/.claude RO overlay bind mounts
After=local-fs.target lima-mounts.target

[Service]
Type=oneshot
ExecStart=/etc/sandbox/apply-claude-overlay.sh

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable sandbox-claude-overlay.service

# ── Nix ───────────────────────────────────────────────────────────────────────
if [ ! -d /nix ]; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
fi
. /etc/profile.d/nix.sh

# ── Flox ──────────────────────────────────────────────────────────────────────
if ! command -v flox >/dev/null 2>&1; then
  TMPF=$(mktemp -t flox.tar.gz.XXXXXX)
  curl -fsSL "{{.FloxURL}}" -o "$TMPF"
  echo "{{.FloxSHA256}}  $TMPF" | sha256sum -c -
  # Flox .deb: extract via ar + tar into /usr/local/
  ar x "$TMPF"
  tar -xzf data.tar.gz -C /usr/local/
  rm -f "$TMPF" debian-binary control.tar.gz data.tar.gz
fi

# ── Claude Code ───────────────────────────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
  TMPC=$(mktemp -t claude.XXXXXX)
  curl -fsSL "{{.ClaudeURL}}" -o "$TMPC"
  echo "{{.ClaudeSHA256}}  $TMPC" | sha256sum -c -
  install -m 0755 "$TMPC" /usr/local/bin/claude
  rm -f "$TMPC"
fi

# ── AGENTS.md ─────────────────────────────────────────────────────────────────
mkdir -p /etc/sandbox
cat > /etc/sandbox/AGENTS.md <<'AGENTS_MD_EOF'
{{.AgentsMarkdown}}
AGENTS_MD_EOF

# Seed the global agents path that Claude Code discovers.
mkdir -p "$USER_HOME/.claude"
ln -sfn /etc/sandbox/AGENTS.md "$USER_HOME/.claude/AGENTS.md" || true
chown -R {{.User}}:{{.User}} "$USER_HOME/.claude"

# ── sandbox-helper unit (placeholder; Phase 9 fills the ExecStart) ───────────
cat > /etc/systemd/system/sandbox-helper.service <<'HELPER_UNIT'
[Unit]
Description=sandbox helper bridge agent (placeholder)
After=network.target

[Service]
Type=simple
ExecStart=/bin/sh -c 'while true; do sleep 86400; done'
Restart=on-failure

[Install]
WantedBy=multi-user.target
HELPER_UNIT
systemctl daemon-reload
systemctl enable sandbox-helper.service

# ── sshd: allow unix socket forwarding (Phase 9 needs StreamLocalBindUnlink) ──
if ! grep -q 'StreamLocalBindUnlink' /etc/ssh/sshd_config 2>/dev/null; then
  echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config
  systemctl restart sshd 2>/dev/null || true
fi
`

// RenderProvision produces the first-boot provision script. It installs:
//   - ~/.claude RO overlay (bind-mounts from /var/sandbox/host-claude/)
//   - Nix multi-user daemon
//   - Flox from .deb package
//   - Claude Code standalone binary
//   - /etc/sandbox/AGENTS.md and ~/.claude/AGENTS.md symlink
//   - sandbox-helper.service placeholder
//   - sshd StreamLocalBindUnlink for Phase 9 bridge forwarding
func RenderProvision(cfg ProvisionConfig) (string, error) {
	t, err := template.New("p").Parse(provisionTmpl)
	if err != nil {
		return "", err
	}
	var b bytes.Buffer
	if err := t.Execute(&b, struct {
		ProvisionConfig
		Subs []string
	}{cfg, subPathsForUnit}); err != nil {
		return "", err
	}
	return b.String(), nil
}

// RenderProvisionSimple is kept for existing tests that don't pass the new
// fields. It renders the overlay-only portion.
func RenderProvisionSimple(cfg ProvisionConfig) (string, error) {
	if cfg.FloxURL == "" && cfg.ClaudeURL == "" {
		// Old simple path for backward-compatible tests
		return renderSimpleProvision(cfg)
	}
	return RenderProvision(cfg)
}

// renderSimpleProvision renders only the claude-overlay section (no Nix/Flox/Claude).
func renderSimpleProvision(cfg ProvisionConfig) (string, error) {
	// Reconstruct the old template for old tests
	oldTmpl := `#!/usr/bin/env bash
set -euo pipefail

USER_HOME="/home/` + cfg.User + `"
HOST_CLAUDE="` + cfg.HostClaudeMountRoot + `"

mkdir -p "$USER_HOME/.claude"
chown -R ` + cfg.User + `:` + cfg.User + ` "$USER_HOME/.claude"

# Apply RO bind mounts for each known subpath (idempotent).
apply_overlays() {
` + strings.Repeat("  #", 1) + rangeOverSubs(cfg) + `apply_overlays

install -d /etc/sandbox
cat > /etc/sandbox/apply-claude-overlay.sh <<'OVERLAY'
#!/usr/bin/env bash
set -euo pipefail
USER_HOME="/home/` + cfg.User + `"
HOST_CLAUDE="` + cfg.HostClaudeMountRoot + `"
` + rangeOverSubs(cfg) + `OVERLAY
chmod +x /etc/sandbox/apply-claude-overlay.sh

cat > /etc/systemd/system/sandbox-claude-overlay.service <<'UNIT'
[Unit]
Description=Re-apply ~/.claude RO overlay bind mounts
After=local-fs.target lima-mounts.target

[Service]
Type=oneshot
ExecStart=/etc/sandbox/apply-claude-overlay.sh

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable sandbox-claude-overlay.service
`
	t, err := template.New("p").Parse(oldTmpl)
	if err != nil {
		return "", err
	}
	var b bytes.Buffer
	if err := t.Execute(&b, nil); err != nil {
		return "", err
	}
	return b.String(), nil
}

func rangeOverSubs(cfg ProvisionConfig) string {
	var b strings.Builder
	for _, s := range subPathsForUnit {
		b.WriteString("if [ -e \"$HOST_CLAUDE/" + s + "\" ]; then\n")
		b.WriteString("  if [ -d \"$HOST_CLAUDE/" + s + "\" ]; then mkdir -p \"$USER_HOME/.claude/" + s + "\"; else [ -e \"$USER_HOME/.claude/" + s + "\" ] || touch \"$USER_HOME/.claude/" + s + "\"; fi\n")
		b.WriteString("  mountpoint -q \"$USER_HOME/.claude/" + s + "\" || mount --bind -o ro \"$HOST_CLAUDE/" + s + "\" \"$USER_HOME/.claude/" + s + "\"\n")
		b.WriteString("fi\n")
	}
	return b.String()
}