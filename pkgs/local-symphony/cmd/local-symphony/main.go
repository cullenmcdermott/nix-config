package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/cli"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/config"
)

func main() {
	cfgPath := config.DefaultPath()
	cfg, err := config.Load(cfgPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "symphony: config: %v\n", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(cfg.DataDir, 0750); err != nil {
		fmt.Fprintf(os.Stderr, "symphony: mkdir: %v\n", err)
		os.Exit(1)
	}

	root := &cobra.Command{
		Use:   "symphony",
		Short: "Local issue tracker for coding agents and humans",
		// Silence cobra's default error printing; we print our own.
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	root.AddCommand(
		cli.NewServeCmd(cfg),
		cli.NewAddCmd(cfg),
		cli.NewLsCmd(cfg),
		cli.NewGetCmd(cfg),
		cli.NewMvCmd(cfg),
		cli.NewNoteCmd(cfg),
		cli.NewHandoffCmd(cfg),
		cli.NewDoneCmd(cfg),
		cli.NewCancelCmd(cfg),
		cli.NewOpenCmd(cfg),
	)

	if err := root.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "symphony: %v\n", err)
		os.Exit(1)
	}
}