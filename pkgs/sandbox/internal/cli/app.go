package cli

import (
	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/lima"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
)

// App holds shared dependencies for cobra subcommands. Tests build one with a
// Fake backend; production wires a real lima.Backend.
type App struct {
	Paths   *paths.Paths
	Backend backend.Backend
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
