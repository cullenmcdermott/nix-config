package cli

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/nixwarm"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newDestroyCmd(app *App) *cobra.Command {
	var force bool
	cmd := &cobra.Command{
		Use:   "destroy",
		Short: "Delete this project's VM and on-host state",
		RunE: func(c *cobra.Command, _ []string) error {
			id, err := app.SelectedVMID(c)
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
				if app.Mutagen != nil {
					if err := app.Mutagen.PauseAll(c.Context(), string(id)); err != nil {
						return fmt.Errorf("mutagen pause: %w", err)
					}
				}
				// Merge VM's /nix/store back into the warm template while the VM is
				// still reachable over SSH. This is done before Backend.Stop so the
				// VM is still running and ssh is available.
				if err := mergeNixIntoWarm(c.Context(), app, id); err != nil {
					return fmt.Errorf("merge /nix into warm template: %w", err)
				}
				if err := app.Backend.Stop(c.Context(), backend.VMID(id)); err != nil {
					return fmt.Errorf("stop before destroy: %w", err)
				}
			}
			// Terminate Mutagen sessions before destroying the backend.
			if app.Mutagen != nil {
				if err := app.Mutagen.TerminateAll(c.Context(), string(id)); err != nil {
					return fmt.Errorf("mutagen terminate: %w", err)
				}
			}
			if err := app.Backend.Destroy(c.Context(), backend.VMID(id)); err != nil {
				_ = state.Write(vp.StateFile, state.StateDestroyFailed)
				return fmt.Errorf("destroy: %w", err)
			}
			if app.Bridge != nil {
				app.Bridge.Stop(vp.BridgeSocket, vp.BridgeToken)
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

// mergeNixIntoWarm rsyncs the VM's /nix/store into the warm template via SSH,
// serialized by the warm template's advisory lock. The VM must be reachable
// (ideally still running) for this to work. If the warm template has no content
// yet, or the VM is not reachable via SSH, this is a no-op.
func mergeNixIntoWarm(ctx context.Context, app *App, id vmid.ID) error {
	warm, err := nixwarm.Open(app.Paths.WarmNixDir)
	if err != nil {
		return err
	}
	hasWarm, err := warm.HasContent()
	if err != nil {
		return err
	}
	if !hasWarm {
		// No warm content yet — nothing to merge.
		return nil
	}
	release, err := warm.Lock(ctx)
	if err != nil {
		return err
	}
	defer release()

	ssh, err := app.Backend.SSHConfig(ctx, backend.VMID(id))
	if err != nil {
		return err
	}
	// Skip if SSH config is not a usable file. The Fake backend used by tests
	// returns "/dev/null" which rsync cannot read — skip merge in that case.
	// Real Lima backends always return a real path inside ~/.lima/.
	if ssh.ConfigFile == "" || ssh.ConfigFile == "/dev/null" {
		return nil
	}
	if _, err := os.Stat(ssh.ConfigFile); err != nil {
		// Config file doesn't exist — VM not reachable.
		return nil
	}

	// rsync from VM:/nix/store/ -> warm/store/
	cmd := exec.CommandContext(ctx, "rsync",
		"-aH", "--delete-after",
		"-e", fmt.Sprintf("ssh -F %s", ssh.ConfigFile),
		ssh.Host+":/nix/store/",
		filepath.Join(warm.Dir, "store")+"/",
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
