package cli

import (
	"context"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/buildinfo"
)

// NewRoot builds a tree wired to a production App. Tests should use
// NewRootForApp directly.
func NewRoot() *cobra.Command {
	app, err := NewProductionApp()
	if err != nil {
		// Defer the error until command execution so callers can recover.
		bad := &cobra.Command{
			Use:  "sandbox",
			RunE: func(*cobra.Command, []string) error { return err },
		}
		return bad
	}
	return NewRootForApp(app)
}

// NewRootForApp builds a tree using an injected App.
func NewRootForApp(app *App) *cobra.Command {
	cmd := &cobra.Command{
		Use:           "sandbox",
		Short:         "Run AI coding agents in per-project Lima VMs",
		SilenceUsage:  true,
		SilenceErrors: true,
		RunE:          func(c *cobra.Command, _ []string) error { return c.Help() },
	}
	cmd.SetVersionTemplate("sandbox {{.Version}}\n")
	cmd.Version = buildinfo.Version()

	cmd.PersistentFlags().String("vm", "", "operate on this VM id (default: derive from cwd)")

	cmd.AddCommand(newStatusCmd(app))
	cmd.AddCommand(newConfigCmd(app))
	cmd.AddCommand(newStartCmd(app))
	cmd.AddCommand(newStopCmd(app))
	cmd.AddCommand(newDestroyCmd(app))
	cmd.AddCommand(newShellCmd(app))
	cmd.AddCommand(newClaudeCmd(app))
	cmd.AddCommand(newMountCmd(app))
	cmd.AddCommand(newVMCmd(app))
	cmd.AddCommand(newBridgedCmd())
	cmd.AddCommand(newOmpCmd(app))
	return cmd
}

func Execute() error { return NewRoot().Execute() }

// ExecuteContext runs the sandbox CLI with the given context, enabling
// graceful cancellation (e.g. on SIGINT).
func ExecuteContext(ctx context.Context) error { return NewRoot().ExecuteContext(ctx) }
