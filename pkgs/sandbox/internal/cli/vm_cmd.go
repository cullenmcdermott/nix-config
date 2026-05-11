package cli

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

func newVMCmd(app *App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "vm",
		Short: "Multi-VM commands",
	}
	cmd.AddCommand(&cobra.Command{
		Use:   "list",
		Short: "List every project VM sandbox knows about",
		RunE: func(c *cobra.Command, _ []string) error {
			return runVMList(c, app)
		},
	})
	cmd.AddCommand(&cobra.Command{
		Use:   "switch <vm-id>",
		Args:  cobra.ExactArgs(1),
		Short: "Print the global flag invocation for working against a specific VM",
		RunE: func(c *cobra.Command, args []string) error {
			fmt.Fprintf(c.OutOrStdout(), "use: sandbox --vm=%s <command>\n", args[0])
			return nil
		},
	})
	return cmd
}

func runVMList(c *cobra.Command, app *App) error {
	// Enumerate from VMsDataDir — it's always created when a VM is first started,
	// whereas VMsConfigDir is only populated when the wizard writes a config file.
	entries, err := os.ReadDir(app.Paths.VMsDataDir)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	live := map[backend.VMID]backend.Status{}
	if infos, err := app.Backend.List(c.Context()); err == nil {
		for _, i := range infos {
			live[i.ID] = i.Status
		}
	}
	// Filter to directories that contain a state file.
	var known []os.DirEntry
	for _, e := range entries {
		if e.IsDir() {
			stateFile := filepath.Join(app.Paths.VMsDataDir, e.Name(), "state.json")
			// Skip phantom entries without a state file. A stray directory
			// (warm-nix placeholder, temp dir) would have no state.json.
			if _, err := os.Stat(stateFile); err != nil {
				continue
			}
			known = append(known, e)
		}
	}
	if len(known) == 0 {
		fmt.Fprintln(c.OutOrStdout(), "no VMs.")
		return nil
	}
	fmt.Fprintf(c.OutOrStdout(), "%-40s %-12s %s\n", "VM ID", "STATE", "BACKEND")
	for _, e := range known {
		stateFile := filepath.Join(app.Paths.VMsDataDir, e.Name(), "state.json")
		s, _ := state.Read(stateFile)
		b := string(live[backend.VMID(e.Name())])
		if b == "" {
			b = "—"
		}
		fmt.Fprintf(c.OutOrStdout(), "%-40s %-12s %s\n", e.Name(), s, b)
	}
	return nil
}
