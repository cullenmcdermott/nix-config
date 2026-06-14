package cli

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/agents"
	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/lima"
	"github.com/cullenmcdermott/system-config/sandbox/internal/mutagen"
	"github.com/cullenmcdermott/system-config/sandbox/internal/nixcache"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

type noWizardKey struct{}

func withNoWizard(ctx context.Context, v bool) context.Context {
	return context.WithValue(ctx, noWizardKey{}, v)
}

func noWizard(ctx context.Context) bool {
	v, _ := ctx.Value(noWizardKey{}).(bool)
	return v
}

func shouldShowWizard(c *cobra.Command, perVMPath string) bool {
	if noWizard(c.Context()) {
		return false
	}
	if !isTTY() && os.Getenv("SANDBOX_FORCE_WIZARD") != "1" {
		return false
	}
	if _, err := os.Stat(perVMPath); err == nil {
		return false
	}
	return true
}

func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

func newStartCmd(app *App) *cobra.Command {
	var noWizardFlag bool
	cmd := &cobra.Command{
		Use:   "start",
		Short: "Create or resume this project's VM",
		RunE: func(c *cobra.Command, _ []string) error {
			ctx := withNoWizard(c.Context(), noWizardFlag)
			c.SetContext(ctx)
			id, err := app.SelectedVMID(c)
			if err != nil {
				return err
			}
			vp := app.Paths.VM(string(id))

			// Persisted state is the source of truth for what to do.
			persisted, err := state.Read(vp.StateFile)
			if err != nil {
				return err
			}
			out := c.OutOrStdout()
			switch persisted {
			case state.StateRunning:
				fmt.Fprintln(out, "VM already running.")
				return nil
			case state.StateNew:
				return doCreate(ctx, c, app, id, vp.StateFile)
			case state.StateStopped:
				return doStart(ctx, c, app, id, vp.StateFile)
			case state.StateProvisioning, state.StateDestroying:
				return fmt.Errorf("VM is %s — wait or recover manually", persisted)
			case state.StateFailed:
				return fmt.Errorf("VM is FAILED — destroy and recreate")
			case state.StateDestroyFailed:
				return fmt.Errorf("VM is DESTROY_FAILED — manual cleanup required (see `sandbox status`)")
			default:
				return fmt.Errorf("VM in unexpected state %s", persisted)
			}
		},
	}
	cmd.Flags().BoolVar(&noWizardFlag, "no-wizard", false, "skip the first-run wizard and accept current defaults")
	return cmd
}

func doCreate(ctx context.Context, c *cobra.Command, app *App, id vmid.ID, statePath string) error {
	p := app.Paths
	vp := p.VM(string(id))

	if app.Wizard != nil && shouldShowWizard(c, vp.ConfigFile) {
		g, err := config.LoadGlobal(p.GlobalConfig)
		if err != nil {
			return err
		}
		v, err := app.Wizard(g)
		if err != nil {
			return fmt.Errorf("wizard: %w", err)
		}
		if err := os.MkdirAll(vp.ConfigDir, 0o755); err != nil {
			return err
		}
		if err := config.SavePerVM(vp.ConfigFile, v); err != nil {
			return err
		}
	}

	r, err := config.LoadResolved(p.GlobalConfig, vp.ConfigFile)
	if err != nil {
		return err
	}
	// The flox deb and omp binary pins are arm64-only (and the Ubuntu image
	// digests in the Lima template likewise); an x86_64 VM would fail mid-
	// provision with a checksum mismatch. Fail fast with a clear message.
	if defaultArch(r.Arch) == "x86_64" {
		return fmt.Errorf("x86_64 VMs are not supported: pinned provisioning artifacts (flox, omp) are arm64-only — remove `arch = \"x86_64\"` from the config")
	}
	projectPath, err := vmid.ProjectPath()
	if err != nil {
		return err
	}

	mounts := BuildMountsWithCache(projectPath, app.Paths.Home, r.Mounts, app.Paths.NixCacheDir)
	if app.Paths.CredentialsDir != "" {
		mounts = append(mounts, backend.Mount{
			HostPath: app.Paths.CredentialsDir,
			VMPath:   CredentialsVMPath,
			Writable: true,
			SyncMode: backend.SyncVirtiofs,
		})
	}
	if app.WrapperBinaryPath != "" {
		mounts = append(mounts, backend.Mount{
			HostPath: filepath.Dir(app.WrapperBinaryPath),
			VMPath:   "/var/sandbox/bin",
			Writable: false,
			SyncMode: backend.SyncVirtiofs,
		})
	}

	provision, err := renderProvisionScript(app, r, projectPath)
	if err != nil {
		return err
	}

	spec := backend.VMSpec{
		ID:        backend.VMID(id),
		CPUs:      r.CPUs,
		MemoryMiB: r.MemoryGiB * 1024,
		DiskGiB:   r.DiskGiB,
		Arch:      defaultArch(r.Arch),
		Mounts:    mounts,
		Provision: backend.ProvisionScript{Script: provision},
	}
	if err := state.Write(statePath, state.StateProvisioning); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "creating VM (first run)… this includes a full Nix + toolchain install and typically takes several minutes")
	if err := app.Backend.Create(c.Context(), spec); err != nil {
		_ = state.Write(statePath, state.StateFailed)
		return fmt.Errorf("create: %w", err)
	}
	// State stays PROVISIONING until Mutagen and the bridge are wired up.
	// If we wrote RUNNING here and Mutagen/bridge then failed, the next
	// `sandbox start` would short-circuit on "already running" and never retry
	// the failed setup (NEW-I-3 / C-I-4). Mark FAILED on any post-create error.
	if err := manageMutagenSessions(ctx, c, app, id, projectPath); err != nil {
		_ = state.Write(statePath, state.StateFailed)
		return err
	}
	if err := startBridgeIfNeeded(ctx, c, app, id); err != nil {
		_ = state.Write(statePath, state.StateFailed)
		return err
	}
	if err := state.Write(statePath, state.StateRunning); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "VM running.")
	return nil
}

func doStart(ctx context.Context, c *cobra.Command, app *App, id vmid.ID, statePath string) error {
	fmt.Fprintln(c.OutOrStdout(), "starting VM…")
	if err := app.Backend.Start(ctx, backend.VMID(id)); err != nil {
		return fmt.Errorf("start: %w", err)
	}
	projectPath, err := vmid.ProjectPath()
	if err != nil {
		return fmt.Errorf("project path: %w", err)
	}
	// Re-apply the provision script so improvements (settings.json, AGENTS.md,
	// version channels, idempotent provisioning fixes) reach existing VMs
	// without requiring destroy+recreate. Best-effort: failures warn-and-
	// continue, because the VM is already up and this is drift convergence,
	// not a correctness gate.
	reapplyProvision(ctx, c, app, id)
	// State stays STOPPED until Mutagen and the bridge are wired up. See the
	// matching comment in doCreate (NEW-I-3 / C-I-4).
	if err := manageMutagenSessions(ctx, c, app, id, projectPath); err != nil {
		_ = state.Write(statePath, state.StateFailed)
		return err
	}
	if err := startBridgeIfNeeded(ctx, c, app, id); err != nil {
		_ = state.Write(statePath, state.StateFailed)
		return err
	}
	if err := state.Write(statePath, state.StateRunning); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "VM running.")
	return nil
}

// renderProvisionScript renders the idempotent VM provision script from the
// current binary's constants and the resolved config. Shared between doCreate
// (which bakes the script into lima.yaml) and doStart (which re-applies a
// freshly rendered copy over SSH to converge drift on existing VMs).
func renderProvisionScript(app *App, r config.Resolved, projectPath string) (string, error) {
	p := app.Paths
	// Ensure the shared host-side Nix binary cache exists and has a signing
	// key. Both are RO-mounted (cache) / referenced (key derives public key)
	// for every VM. The mount is added unconditionally — an empty cache is
	// just a substituter miss; gating on content would deadlock bootstrap.
	cache, err := nixcache.Open(p.NixCacheDir)
	if err != nil {
		return "", err
	}
	if err := cache.Ensure(); err != nil {
		return "", err
	}
	pubKey, err := nixcache.EnsureKey(p.NixCacheKey)
	if err != nil {
		return "", err
	}
	return lima.RenderProvision(lima.ProvisionConfig{
		User:                currentUsername(),
		ProjectPath:         projectPath,
		HostClaudeMountRoot: HostClaudeMountRoot,
		FloxVersion:         FloxVersion,
		FloxURL:             FloxURL,
		FloxSHA256:          FloxSHA256,
		ClaudeGCSBase:       ClaudeGCSBase(),
		ClaudeChannel:       ClaudeChannel,
		ClaudePlatform:      archToPlatform(defaultArch(r.Arch)),
		AgentsMarkdown:      agents.MarkdownContent() + writableMountsSection(r.Mounts),
		ClaudeSubpaths:      ClaudeSubpaths,
		SettingsJSON:        buildVMSettings(p.Home),
		OmpVersion:          OmpVersion,
		OmpURL:              BuildOmpURL(OmpVersion, defaultArch(r.Arch)),
		OmpSHA256:           OmpSHA256,
		HostOmpMountRoot:    HostOmpMountRoot,
		OmpSubpaths:         OmpSubpaths,
		OmpConfigYAML:       buildOmpVMConfig(p.Home),
		OmpAgentsMarkdown:   agents.OmpMarkdownContent() + writableMountsSection(r.Mounts),
		NixCachePublicKey:   pubKey,
		NixCacheVMPath:      NixCacheVMPath,
		CredentialsVMPath:   CredentialsVMPath,
	})
}

// writableMountsSection generates an AGENTS.md addendum listing extra mounts
// that are writable from inside the VM, so agents know the "nothing here can
// affect the host" promise does not cover those paths. Returns "" when no
// extra mount is writable. Regenerated on every start via provision re-apply,
// so it tracks the current config.
func writableMountsSection(mounts []config.Mount) string {
	var b strings.Builder
	for _, m := range mounts {
		if !m.Writable {
			continue
		}
		if b.Len() == 0 {
			b.WriteString("\n### Writable host mounts — EXCEPTIONS to isolation\n\n" +
				"The following host directories are mounted WRITABLE in this VM. " +
				"Changes under these paths DO affect the host machine — treat them " +
				"with the same care as host files, and confirm with the user before " +
				"destructive operations there:\n\n")
		}
		fmt.Fprintf(&b, "- `%s` (host) ↔ `%s` (VM)\n", m.HostPath, m.VMPath)
	}
	return b.String()
}

// reapplyProvision re-renders the provision script and applies it inside the
// VM over SSH. Best-effort: silently skips when no usable SSH config is
// available (fake backend, VM not reachable), and on apply failure prints a
// warning instead of returning an error. The provision script is designed
// idempotent so re-running it on a live VM is safe.
func reapplyProvision(ctx context.Context, c *cobra.Command, app *App, id vmid.ID) {
	ssh, err := app.Backend.SSHConfig(ctx, backend.VMID(id))
	if err != nil {
		return
	}
	if ssh.ConfigFile == "" || ssh.ConfigFile == "/dev/null" {
		return
	}
	if _, err := os.Stat(ssh.ConfigFile); err != nil {
		return
	}

	vp := app.Paths.VM(string(id))
	r, err := config.LoadResolved(app.Paths.GlobalConfig, vp.ConfigFile)
	if err != nil {
		fmt.Fprintf(c.ErrOrStderr(), "warning: provision re-apply failed (continuing): load config: %v\n", err)
		return
	}
	projectPath, err := vmid.ProjectPath()
	if err != nil {
		fmt.Fprintf(c.ErrOrStderr(), "warning: provision re-apply failed (continuing): project path: %v\n", err)
		return
	}
	script, err := renderProvisionScript(app, r, projectPath)
	if err != nil {
		fmt.Fprintf(c.ErrOrStderr(), "warning: provision re-apply failed (continuing): render: %v\n", err)
		return
	}

	fmt.Fprintln(c.OutOrStdout(), "re-applying provision…")
	cmd := exec.CommandContext(ctx, "ssh", "-F", ssh.ConfigFile, ssh.Host, "sudo", "bash", "-s")
	cmd.Stdin = strings.NewReader(script)
	var combined bytes.Buffer
	cmd.Stdout = &combined
	cmd.Stderr = &combined
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(c.ErrOrStderr(), "warning: provision re-apply failed (continuing): %v\n%s\n",
			err, tailLines(combined.String(), 20))
		return
	}
	fmt.Fprintln(c.OutOrStdout(), "provision re-applied.")
}

// tailLines returns at most the last n lines of s, joined by "\n". Used to
// keep error messages short while still surfacing the failing command's tail.
func tailLines(s string, n int) string {
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	if len(lines) <= n {
		return strings.Join(lines, "\n")
	}
	return strings.Join(lines[len(lines)-n:], "\n")
}

// manageMutagenSessions creates Mutagen sync sessions on first boot, or resumes
// existing ones on subsequent starts.
func manageMutagenSessions(ctx context.Context, c *cobra.Command, app *App, id vmid.ID, projectPath string) error {
	if app.Mutagen == nil {
		return nil
	}
	// Ensure the system SSH can resolve Lima's per-VM host aliases so that
	// mutagen (which calls ssh directly) can connect to the VM.
	if err := ensureSSHConfigInclude(app.Paths.Home); err != nil {
		return fmt.Errorf("ssh config include: %w", err)
	}
	// Ensure the Mutagen daemon is running before any sync operation. This is
	// idempotent and gives first-time users a clear error path (E-I-4).
	if err := app.Mutagen.EnsureDaemon(ctx); err != nil {
		return err
	}
	ssh, err := app.Backend.SSHConfig(ctx, backend.VMID(id))
	if err != nil {
		return err
	}
	// Resolve the VM user's actual home directory — Lima may create it as
	// /home/<user>.linux rather than /home/<user>.
	vmHome, err := resolveVMHome(ctx, ssh)
	if err != nil {
		// Fall back to /home/<user> if we can't resolve it.
		vmHome = "/home/" + os.Getenv("USER")
	}
	r, err := config.LoadResolved(app.Paths.GlobalConfig, app.Paths.VM(string(id)).ConfigFile)
	if err != nil {
		return err
	}
	spec := mutagen.Spec{
		VMID:        string(id),
		HostPath:    projectPath,
		VMPath:      projectPath,
		HomeDir:     app.Paths.Home,
		LimaSSHHost: ssh.Host,
		VMHome:      vmHome,
		SyncVCS:     r.SyncGit,
	}
	sessions, err := app.Mutagen.SessionsFor(ctx, string(id))
	if err != nil {
		return fmt.Errorf("mutagen session list: %w", err)
	}

	// Check which sessions exist and create only the missing ones (E-I-3).
	// This recovers from partial session creation (e.g. project succeeds but
	// one of the transcript subs fails). Mutagen errors on duplicate session
	// names, so we must not recreate sessions that already exist (NEW-I-2).
	projectName := "sandbox-" + string(id) + "-project"
	hasProject := false
	var projectSession mutagen.Session
	existingTranscripts := map[string]bool{}
	for _, s := range sessions {
		if strings.Contains(s.Name, projectName) {
			hasProject = true
			projectSession = s
		}
		for _, sub := range mutagen.TranscriptSubs {
			if strings.Contains(s.Name, "sandbox-"+string(id)+"-transcripts-"+sub) {
				existingTranscripts[sub] = true
			}
		}
	}

	// Mutagen can't change --ignore-vcs on a live session, so a sync_git
	// config change means terminate + recreate the project session. The
	// sandbox-vcs label records the mode each session was created with;
	// pre-label sessions parse as SyncVCS=false, which matches how they were
	// created (always --ignore-vcs).
	if hasProject && projectSession.SyncVCS != spec.SyncVCS {
		fmt.Fprintf(c.OutOrStdout(), "sync_git changed to %t — recreating project sync session…\n", spec.SyncVCS)
		if err := app.Mutagen.Terminate(ctx, projectSession.Name); err != nil {
			return fmt.Errorf("mutagen terminate project session: %w", err)
		}
		hasProject = false
	}
	missingTranscripts := []string{}
	for _, sub := range mutagen.TranscriptSubs {
		if !existingTranscripts[sub] {
			missingTranscripts = append(missingTranscripts, sub)
		}
	}

	created := false
	if !hasProject {
		fmt.Fprintln(c.OutOrStdout(), "creating Mutagen sync sessions…")
		if err := app.Mutagen.CreateProject(ctx, spec); err != nil {
			return fmt.Errorf("mutagen project session: %w", err)
		}
		created = true
	}
	if len(missingTranscripts) > 0 {
		if !created {
			fmt.Fprintln(c.OutOrStdout(), "creating Mutagen sync sessions…")
		}
		if err := app.Mutagen.CreateTranscripts(ctx, spec, missingTranscripts); err != nil {
			return fmt.Errorf("mutagen transcripts session: %w", err)
		}
		created = true
	}

	if created {
		fmt.Fprintln(c.OutOrStdout(), "sync sessions created.")
	}

	// Resume any paused sessions. ResumeAll is safe to call even if sessions
	// are already running (mutagen exits 0 for already-running sessions).
	if len(sessions) > 0 {
		fmt.Fprintln(c.OutOrStdout(), "resuming sync sessions…")
		if err := app.Mutagen.ResumeAll(ctx, string(id)); err != nil {
			return fmt.Errorf("mutagen resume: %w", err)
		}
		fmt.Fprintln(c.OutOrStdout(), "sync sessions resumed.")
	}
	return nil
}

// defaultArch returns the user's chosen arch, or "aarch64" if empty.
func defaultArch(s string) string {
	if s == "" {
		return "aarch64"
	}
	return s
}

func currentUsername() string {
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	if u, err := user.Current(); err == nil {
		return u.Username
	}
	return "user"
}

// archToPlatform maps our "aarch64"/"x86_64" arch string to the linux
// platform key used in the GCS URL. The VM is always Linux regardless of
// the host OS, so we never return a darwin-* key here.
func archToPlatform(arch string) string {
	switch arch {
	case "x86_64":
		return "linux-x64"
	default:
		return "linux-arm64"
	}
}

// startBridgeIfNeeded spawns the host bridge daemon, writes the PID file, and
// pushes the session token into the VM. It is a no-op when app.Bridge is nil.
func startBridgeIfNeeded(ctx context.Context, c *cobra.Command, app *App, id vmid.ID) error {
	if app.Bridge == nil {
		return nil
	}
	vp := app.Paths.VM(string(id))
	token := newRandomToken()
	proc, err := app.Bridge.Start(vp.BridgeSocket, vp.BridgeToken, token)
	if err != nil {
		return fmt.Errorf("start bridge: %w", err)
	}
	pidPath := filepath.Join(vp.DataDir, "bridge.pid")
	_ = os.WriteFile(pidPath, []byte(fmt.Sprintf("%d\n", proc.Pid)), 0o644)

	ssh, err := app.Backend.SSHConfig(ctx, backend.VMID(id))
	if err != nil {
		// Non-fatal: bridge is running; token push can fail if VM not yet reachable.
		fmt.Fprintf(c.ErrOrStderr(), "warning: could not get SSH config to push bridge token: %v\n", err)
		return nil
	}
	if err := writeTokenIntoVM(ctx, ssh, token); err != nil {
		fmt.Fprintf(c.ErrOrStderr(), "warning: could not push bridge token into VM: %v\n", err)
	}
	return nil
}

// writeTokenIntoVM writes the bridge session token to /etc/sandbox/bridge-token
// inside the VM via SSH + sudo. Mode 0600: the token authorizes host-side
// secret reads, so it must not be readable by arbitrary VM processes.
func writeTokenIntoVM(ctx context.Context, ssh backend.SSHConfig, token string) error {
	cmd := exec.CommandContext(ctx, "ssh", "-F", ssh.ConfigFile, ssh.Host,
		"sudo", "sh", "-c",
		"'umask 077 && cat > /etc/sandbox/bridge-token && chmod 600 /etc/sandbox/bridge-token && chown \"$SUDO_USER\" /etc/sandbox/bridge-token'")
	cmd.Stdin = strings.NewReader(token + "\n")
	return cmd.Run()
}

// newRandomToken returns a cryptographically random 32-byte hex string.
func newRandomToken() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// resolveVMHome queries the VM for the current user's home directory via SSH.
// Lima may create the home at /home/<user>.linux rather than /home/<user>.
func resolveVMHome(ctx context.Context, ssh backend.SSHConfig) (string, error) {
	cmd := exec.CommandContext(ctx, "ssh", "-F", ssh.ConfigFile, ssh.Host,
		"echo", "$HOME")
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	home := strings.TrimSpace(string(out))
	if home == "" {
		return "", fmt.Errorf("empty $HOME from VM")
	}
	return home, nil
}

// buildVMSettings reads the host's ~/.claude/settings.json, strips fields that
// don't apply in the VM (permissions, sandbox), and rewrites the statusLine
// command to reference the VM-installed binary.  Returns the JSON string to
// embed in the provision template, or "" if the host file can't be read.
func buildVMSettings(homeDir string) string {
	hostPath := filepath.Join(homeDir, ".claude", "settings.json")
	data, err := os.ReadFile(hostPath)
	if err != nil {
		// No host settings — return minimal statusline-only config.
		b, _ := json.MarshalIndent(map[string]any{
			"statusLine": map[string]string{
				"type":    "command",
				"command": "/usr/local/bin/claude-statusline",
			},
		}, "", "  ")
		return string(b)
	}

	var settings map[string]any
	if json.Unmarshal(data, &settings) != nil {
		return ""
	}

	// Drop host-specific keys that don't apply in the VM.
	delete(settings, "permissions") // --dangerously-skip-permissions handles this
	delete(settings, "sandbox")     // already inside the sandbox

	// Point the statusline at the VM-installed binary.
	settings["statusLine"] = map[string]string{
		"type":    "command",
		"command": "/usr/local/bin/claude-statusline",
	}

	b, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return ""
	}
	return string(b)
}

// buildOmpVMConfig reads the host's ~/.config/omp/agent/config.yml, rewrites
// sessionDir to a VM-local path, and returns the YAML string to embed in the
// provision template. Returns "" if the host file can't be read.
func buildOmpVMConfig(homeDir string) string {
	hostPath := filepath.Join(homeDir, ".config", "omp", "agent", "config.yml")
	data, err := os.ReadFile(hostPath)
	if err != nil {
		return ""
	}

	var config map[string]any
	if yaml.Unmarshal(data, &config) != nil {
		return ""
	}

	// Rewrite sessionDir to VM-local path. The exact home directory is
	// resolved at shell time via $HOME, but config.yml needs a concrete
	// path. Use a standard Linux home path — the provision script will
	// create it.
	config["sessionDir"] = "~/.local/state/omp/sessions"

	b, err := yaml.Marshal(config)
	if err != nil {
		return ""
	}
	return string(b)
}
