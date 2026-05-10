package cli

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
)

func newMountCmd(app *App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mount",
		Short: "Manage extra host-directory mounts for this project's VM",
	}
	cmd.AddCommand(&cobra.Command{
		Use:   "add <host-path>",
		Args:  cobra.ExactArgs(1),
		Short: "Add a writable bind mount at the same path inside the VM",
		RunE: func(c *cobra.Command, args []string) error {
			return mountChange(c, app, args[0], true)
		},
	})
	cmd.AddCommand(&cobra.Command{
		Use:   "rm <host-path>",
		Args:  cobra.ExactArgs(1),
		Short: "Remove a previously-added mount",
		RunE: func(c *cobra.Command, args []string) error {
			return mountChange(c, app, args[0], false)
		},
	})
	return cmd
}

func mountChange(c *cobra.Command, app *App, hostPath string, add bool) error {
	abs, err := filepath.Abs(hostPath)
	if err != nil {
		return err
	}
	id, err := app.SelectedVMID(c)
	if err != nil {
		return err
	}
	vp := app.Paths.VM(string(id))

	v, err := config.LoadPerVM(vp.ConfigFile)
	if err != nil {
		return err
	}
	if add {
		for _, m := range v.Mounts {
			if m.HostPath == abs {
				fmt.Fprintln(c.OutOrStdout(), "mount already present.")
				return nil
			}
		}
		v.Mounts = append(v.Mounts, config.Mount{HostPath: abs, VMPath: abs, Writable: true})
	} else {
		out := v.Mounts[:0]
		removed := false
		for _, m := range v.Mounts {
			if m.HostPath == abs {
				removed = true
				continue
			}
			out = append(out, m)
		}
		if !removed {
			return fmt.Errorf("mount %q not found", abs)
		}
		v.Mounts = out
	}
	if err := os.MkdirAll(vp.ConfigDir, 0o755); err != nil {
		return err
	}
	if err := config.SavePerVM(vp.ConfigFile, v); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "config updated. Restart the VM for changes to take effect: sandbox stop && sandbox start")
	return nil
}
