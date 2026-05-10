package cli

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newDestroyCmd(app *App) *cobra.Command {
	var force bool
	cmd := &cobra.Command{
		Use:   "destroy",
		Short: "Delete this project's VM and on-host state",
		RunE: func(c *cobra.Command, _ []string) error {
			id, err := vmid.ForCwd()
			if err != nil {
				return err
			}
			vp := app.Paths.VM(string(id))
			persisted, err := state.Read(vp.StateFile)
			if err != nil {
				return err
			}
			if persisted == state.StateRunning && !force {
				return fmt.Errorf("VM is RUNNING — pass --force or run `sandbox stop` first")
			}
			if persisted == state.StateNew {
				fmt.Fprintln(c.OutOrStdout(), "nothing to destroy.")
				return nil
			}
			if err := state.Write(vp.StateFile, state.StateDestroying); err != nil {
				return err
			}
			if persisted == state.StateRunning {
				if err := app.Backend.Stop(c.Context(), backend.VMID(id)); err != nil {
					return fmt.Errorf("stop before destroy: %w", err)
				}
			}
			if err := app.Backend.Destroy(c.Context(), backend.VMID(id)); err != nil {
				_ = state.Write(vp.StateFile, state.StateDestroyFailed)
				return fmt.Errorf("destroy: %w", err)
			}
			if err := os.RemoveAll(vp.DataDir); err != nil {
				return err
			}
			if err := os.RemoveAll(vp.ConfigDir); err != nil {
				return err
			}
			fmt.Fprintln(c.OutOrStdout(), "VM destroyed.")
			return nil
		},
	}
	cmd.Flags().BoolVar(&force, "force", false, "destroy even if the VM is currently running")
	return cmd
}
