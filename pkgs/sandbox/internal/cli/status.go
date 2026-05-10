package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

func newStatusCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show this project's VM state and resolved config",
		RunE: func(c *cobra.Command, _ []string) error {
			id, err := app.SelectedVMID(c)
			if err != nil {
				return err
			}
			p := app.Paths
			vp := p.VM(string(id))
			s, err := state.Read(vp.StateFile)
			if err != nil {
				return err
			}
			r, err := config.LoadResolved(p.GlobalConfig, vp.ConfigFile)
			if err != nil {
				return err
			}
			out := c.OutOrStdout()
			fmt.Fprintf(out, "VM ID: %s\n", id)
			fmt.Fprintf(out, "State: %s\n", s)
			fmt.Fprintf(out, "Config:\n")
			fmt.Fprintf(out, "  cpus: %d\n", r.CPUs)
			fmt.Fprintf(out, "  memory: %d GiB\n", r.MemoryGiB)
			fmt.Fprintf(out, "  disk: %d GiB\n", r.DiskGiB)
			fmt.Fprintf(out, "  agent: %s\n", r.Agent)
			if r.Arch != "" {
				fmt.Fprintf(out, "  arch: %s\n", r.Arch)
			}
			if len(r.Mounts) > 0 {
				fmt.Fprintf(out, "  mounts:\n")
				for _, m := range r.Mounts {
					fmt.Fprintf(out, "    - %s -> %s (writable=%t)\n", m.HostPath, m.VMPath, m.Writable)
				}
			}
			if app.Mutagen != nil {
				sessions, err := app.Mutagen.SessionsFor(c.Context(), string(id))
				if err == nil && len(sessions) > 0 {
					fmt.Fprintln(out, "Sync sessions:")
					for _, sess := range sessions {
						fmt.Fprintf(out, "  %s: %s\n", sess.Name, sess.Status)
					}
				}
			}
			return nil
		},
	}
}
