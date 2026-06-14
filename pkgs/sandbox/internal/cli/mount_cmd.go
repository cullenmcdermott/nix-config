package cli

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
)

func newMountCmd(app *App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mount",
		Short: "Manage extra host-directory mounts for this project's VM",
	}
	var rw bool
	addCmd := &cobra.Command{
		Use:   "add <host-path>",
		Args:  cobra.ExactArgs(1),
		Short: "Add a read-only bind mount at the same path inside the VM (--rw for writable)",
		RunE: func(c *cobra.Command, args []string) error {
			return mountChange(c, app, args[0], true, rw)
		},
	}
	addCmd.Flags().BoolVar(&rw, "rw", false, "mount writable — the VM can then modify this host directory")
	cmd.AddCommand(addCmd)
	cmd.AddCommand(&cobra.Command{
		Use:   "rm <host-path>",
		Args:  cobra.ExactArgs(1),
		Short: "Remove a previously-added mount",
		RunE: func(c *cobra.Command, args []string) error {
			return mountChange(c, app, args[0], false, false)
		},
	})
	return cmd
}

func mountChange(c *cobra.Command, app *App, hostPath string, add, writable bool) error {
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
		for i, m := range v.Mounts {
			if m.HostPath == abs {
				if m.Writable == writable {
					fmt.Fprintln(c.OutOrStdout(), "mount already present.")
					return nil
				}
				v.Mounts[i].Writable = writable
				return saveMounts(c, vp, v)
			}
		}
		v.Mounts = append(v.Mounts, config.Mount{HostPath: abs, VMPath: abs, Writable: writable})
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
	return saveMounts(c, vp, v)
}

func saveMounts(c *cobra.Command, vp paths.VMPaths, v config.PerVM) error {
	if err := os.MkdirAll(vp.ConfigDir, 0o755); err != nil {
		return err
	}
	if err := config.SavePerVM(vp.ConfigFile, v); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "config updated. Restart the VM for changes to take effect: sandbox stop && sandbox start")
	return nil
}
