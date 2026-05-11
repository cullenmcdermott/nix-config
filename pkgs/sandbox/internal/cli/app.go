package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/lima"
	"github.com/cullenmcdermott/system-config/sandbox/internal/mutagen"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
	"github.com/cullenmcdermott/system-config/sandbox/internal/wizard"
)

// SSHExecer is the function signature for executing ssh into a VM.
type SSHExecer func(configFile, host string, forwards, args []string) error

// SelectedVMID returns the VM ID from the --vm flag when set, or derives it
// from the current working directory.
func (a *App) SelectedVMID(c *cobra.Command) (vmid.ID, error) {
	if v, _ := c.Root().PersistentFlags().GetString("vm"); v != "" {
		return vmid.ID(v), nil
	}
	return vmid.ForCwd()
}

// WizardFunc lets tests stub out the interactive form.
type WizardFunc func(global config.Global) (config.PerVM, error)

// App holds shared dependencies for cobra subcommands. Tests build one with a
// Fake backend; production wires a real lima.Backend.
type App struct {
	Paths             *paths.Paths
	Backend           backend.Backend
	Mutagen           *mutagen.Manager
	Wizard            WizardFunc
	Bridge            *BridgeSupervisor
	WrapperBinaryPath string // path to sandbox-claude linux binary; set via SANDBOX_CLAUDE_WRAPPER env
	sshExec           SSHExecer
}

// ExecSSH runs ssh into the VM, using the injectable sshExec if set.
// forwards is a list of remote-forward specs passed as -R flags (before the host).
func (a *App) ExecSSH(configFile, host string, forwards []string, args []string) error {
	if a.sshExec != nil {
		return a.sshExec(configFile, host, forwards, args)
	}
	base := []string{"-F", configFile, "-t"}
	for _, f := range forwards {
		base = append(base, "-R", f)
	}
	base = append(base, host)
	base = append(base, args...)
	return syscallExec("ssh", base)
}

// BridgeSupervisor manages the per-VM sandbox-bridged subprocess.
type BridgeSupervisor struct {
	Self string // absolute path to the sandbox binary
}

// Start spawns sandbox bridged as a detached daemon, writes the token to
// tokenPath, and returns the new process handle. The process outlives the
// calling sandbox start command.
func (b *BridgeSupervisor) Start(socketPath, tokenPath, token string) (*os.Process, error) {
	if err := os.WriteFile(tokenPath, []byte(token+"\n"), 0o600); err != nil {
		return nil, err
	}
	cmd := exec.Command(b.Self, "bridged", "--socket="+socketPath, "--token="+token)
	// Detach from the parent's process group so the daemon keeps running after
	// sandbox start exits.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	return cmd.Process, nil
}

// Stop sends SIGTERM to the bridge daemon and removes socket/token/pid files.
func (b *BridgeSupervisor) Stop(socketPath, tokenPath string) error {
	pidPath := filepath.Join(filepath.Dir(socketPath), "bridge.pid")
	if data, err := os.ReadFile(pidPath); err == nil {
		var pid int
		// PID file may be empty/garbage from a crash; pid stays 0 and the
		// guard below skips the kill.
		_, _ = fmt.Sscanf(string(data), "%d", &pid)
		if pid > 0 {
			_ = syscall.Kill(pid, syscall.SIGTERM)
		}
	}
	_ = os.Remove(socketPath)
	_ = os.Remove(tokenPath)
	_ = os.Remove(pidPath)
	return nil
}

// makeProductionWizard returns a WizardFunc that loads/saves mount history
// from p.MountHistoryFile and passes it to the TUI for quick re-selection.
func makeProductionWizard(p *paths.Paths) WizardFunc {
	return func(g config.Global) (config.PerVM, error) {
		history, _ := wizard.LoadHistory(p.MountHistoryFile) // best-effort

		currentPath, _ := vmid.ProjectPath() // best-effort; empty string is safe

		f, err := wizard.Run(wizard.NewForm(g), wizard.RunOptions{
			History:     history,
			CurrentPath: currentPath,
		})
		if err != nil {
			return config.PerVM{}, err
		}

		// Record selected mounts in history, ranked by recency.
		now := time.Now()
		updated := make([]wizard.HistoryEntry, 0, len(f.ExtraMounts))
		for _, mp := range f.ExtraMounts {
			updated = append(updated, wizard.HistoryEntry{Path: mp, LastUsed: now})
		}
		_ = wizard.SaveHistory(p.MountHistoryFile, updated) // best-effort

		return f.Apply(), nil
	}
}

// NewProductionApp wires the real Lima backend.
func NewProductionApp() (*App, error) {
	p, err := paths.Resolve()
	if err != nil {
		return nil, err
	}
	if err := p.EnsureDirs(); err != nil {
		return nil, err
	}
	self, err := os.Executable()
	if err != nil {
		return nil, err
	}
	return &App{
		Paths:             p,
		Backend:           lima.New(lima.NewRunner(""), p.VMsConfigDir),
		Mutagen:           mutagen.New(mutagen.NewRunner("")),
		Wizard:            makeProductionWizard(p),
		Bridge:            &BridgeSupervisor{Self: self},
		WrapperBinaryPath: os.Getenv("SANDBOX_CLAUDE_WRAPPER"),
	}, nil
}
