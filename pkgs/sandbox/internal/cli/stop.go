package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newStopCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:   "stop",
		Short: "Stop this project's VM",
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
			switch persisted {
			case state.StateRunning:
				if app.Mutagen != nil {
					if err := app.Mutagen.PauseAll(c.Context(), string(id)); err != nil {
						fmt.Fprintf(c.ErrOrStderr(), "warning: mutagen pause failed (continuing stop): %v\n", err)
					}
				}
				if app.Bridge != nil {
					app.Bridge.Stop(vp.BridgeSocket, vp.BridgeToken)
				}
				if err := app.Backend.Stop(c.Context(), backend.VMID(id)); err != nil {
					return err
				}
				return state.Write(vp.StateFile, state.StateStopped)
			case state.StateStopped:
				fmt.Fprintln(c.OutOrStdout(), "VM already stopped.")
				return nil
			case state.StateNew:
				fmt.Fprintln(c.OutOrStdout(), "no VM exists for this project.")
				return nil
			default:
				return fmt.Errorf("VM in state %s — refusing to stop", persisted)
			}
		},
	}
}