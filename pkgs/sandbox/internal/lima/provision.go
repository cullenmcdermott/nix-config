package lima

import (
	"bytes"
	"text/template"
)

type ProvisionConfig struct {
	User                string
	HostClaudeMountRoot string
}

var subPathsForUnit = []string{"skills", "commands", "agents", "hooks", "CLAUDE.md", "settings.json"}

const provisionTmpl = `#!/usr/bin/env bash
set -euo pipefail

USER_HOME="/home/{{.User}}"
HOST_CLAUDE="{{.HostClaudeMountRoot}}"

mkdir -p "$USER_HOME/.claude"
chown -R {{.User}}:{{.User}} "$USER_HOME/.claude"

# Apply RO bind mounts for each known subpath (idempotent).
apply_overlays() {
{{range .Subs}}  if [ -e "$HOST_CLAUDE/{{.}}" ]; then
    mkdir -p "$(dirname "$USER_HOME/.claude/{{.}}")"
    if [ -d "$HOST_CLAUDE/{{.}}" ]; then
      mkdir -p "$USER_HOME/.claude/{{.}}"
    else
      [ -e "$USER_HOME/.claude/{{.}}" ] || touch "$USER_HOME/.claude/{{.}}"
    fi
    mountpoint -q "$USER_HOME/.claude/{{.}}" || mount --bind -o ro "$HOST_CLAUDE/{{.}}" "$USER_HOME/.claude/{{.}}"
  fi
{{end}}}
apply_overlays

# Install a systemd unit that re-applies on every boot (rootfs survives, but
# bind mounts do not).
install -d /etc/sandbox
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
`

// RenderProvision produces the first-boot provision script that:
//   - Creates ~/.claude/ in the user's home
//   - Bind-mounts each host RO subpath onto ~/.claude/<sub>
//   - Installs a systemd unit to re-apply bind mounts on subsequent boots
func RenderProvision(cfg ProvisionConfig) (string, error) {
	t, err := template.New("p").Parse(provisionTmpl)
	if err != nil {
		return "", err
	}
	var b bytes.Buffer
	if err := t.Execute(&b, struct {
		User                string
		HostClaudeMountRoot string
		Subs                []string
	}{cfg.User, cfg.HostClaudeMountRoot, subPathsForUnit}); err != nil {
		return "", err
	}
	return b.String(), nil
}