package cli

import (
	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/lima"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
)

// SSHExecer is the function signature for executing ssh into a VM.
type SSHExecer func(configFile, host string, args []string) error

// App holds shared dependencies for cobra subcommands. Tests build one with a
// Fake backend; production wires a real lima.Backend.
type App struct {
	Paths   *paths.Paths
	Backend backend.Backend
	sshExec SSHExecer
}

// ExecSSH runs ssh into the VM, using the injectable sshExec if set.
func (a *App) ExecSSH(configFile, host string, args []string) error {
	if a.sshExec != nil {
		return a.sshExec(configFile, host, args)
	}
	// Real ssh exec — uses syscall.Exec on Unix so the user inherits the tty
	// without an intermediate Go process.
	allArgs := append([]string{"-F", configFile, "-t", host}, args...)
	return syscallExec("ssh", allArgs)
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
	return &App{
		Paths:   p,
		Backend: lima.New(lima.NewRunner(""), p.VMsConfigDir),
	}, nil
}
