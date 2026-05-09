// Package cli wires the sandbox command tree.
package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/buildinfo"
)

// NewRoot returns a fresh cobra root command. Each call returns a new tree so
// tests can run independently.
func NewRoot() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "sandbox",
		Short: "Run AI coding agents in per-project Lima VMs",
		// Default behaviour with no subcommand: print help.
		RunE: func(c *cobra.Command, args []string) error {
			return c.Help()
		},
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	cmd.SetVersionTemplate("sandbox {{.Version}}\n")
	cmd.Version = buildinfo.Version()
	return cmd
}

// Execute is the canonical CLI entrypoint used by main.
func Execute() error {
	cmd := NewRoot()
	return cmd.Execute()
}

// Compile-time check that fmt is referenced if we later need it; remove when
// real subcommands land.
var _ = fmt.Sprint
