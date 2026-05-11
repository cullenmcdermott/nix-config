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

type destroyStep struct {
	id   string
	desc string
	fn   func(ctx context.Context) error
}

func newDestroyCmd(app *App) *cobra.Command {
	var force, recover bool
	cmd := &cobra.Command{
		Use:   "destroy",
		Short: "Delete this project's VM and on-host state",
		RunE: func(c *cobra.Command, _ []string) error {
			id, err := app.SelectedVMID(c)
			if err != nil {
				return err
			}
			vp := app.Paths.VM(string(id))
			rec, err := state.ReadRecord(vp.StateFile)
			if err != nil {
				return err
			}

			switch rec.State {
			case state.StateRunning:
				if !force {
					return fmt.Errorf("VM is RUNNING — pass --force or run `sandbox stop` first")
				}
			case state.StateNew:
				fmt.Fprintln(c.OutOrStdout(), "nothing to destroy.")
				return nil
			case state.StateDestroyFailed:
				if !recover {
					return fmt.Errorf("VM is DESTROY_FAILED at step %q — re-run with --recover to resume", rec.LastFailedStep)
				}
			}

			steps := []destroyStep{
				{
					"vm-stop", "stop VM",
					func(ctx context.Context) error {
						// Always attempt Stop. Lima's limactl stop is idempotent —
						// it succeeds even if the VM is already stopped. We used to
						// guard on rec.State != RUNNING, but that skipped the stop
						// on DESTROY_FAILED recovery (C-I-2). The VM might still be
						// running in that case; attempt Stop regardless.
						if app.Mutagen != nil {
							if err := app.Mutagen.PauseAll(ctx, string(id)); err != nil {
								fmt.Fprintf(c.ErrOrStderr(), "warning: mutagen pause failed (continuing): %v\n", err)
							}
						}
						if err := mergeNixIntoWarm(ctx, app, id); err != nil {
							// Best-effort. The warm cache is an optimization, not a
							// correctness requirement. If the VM is unreachable or the
							// rsync fails, we still want to destroy it (C-I-3).
							fmt.Fprintf(c.ErrOrStderr(), "warning: merging /nix into warm template failed (continuing): %v\n", err)
						}
						return app.Backend.Stop(ctx, backend.VMID(id))
					},
				},
				{
					"bridge-stop", "stop bridge daemon",
					func(ctx context.Context) error {
						if app.Bridge != nil {
							app.Bridge.Stop(vp.BridgeSocket, vp.BridgeToken)
						}
						return nil
					},
				},
				{
					"mutagen-terminate", "terminate Mutagen sessions",
					func(ctx context.Context) error {
						if app.Mutagen == nil {
							return nil
						}
						return app.Mutagen.TerminateAll(ctx, string(id))
					},
				},
				{
					"backend-destroy", "delete Lima instance",
					func(ctx context.Context) error {
						return app.Backend.Destroy(ctx, backend.VMID(id))
					},
				},
				{
					"remove-host-state", "remove host state files",
					func(ctx context.Context) error {
						if err := os.RemoveAll(vp.DataDir); err != nil {
							return err
						}
						return os.RemoveAll(vp.ConfigDir)
					},
				},
			}

			// Find resume point when recovering.
			start := 0
			if rec.State == state.StateDestroyFailed {
				for i, s := range steps {
					if s.id == rec.LastFailedStep {
						start = i
						break
					}
				}
			}

			// Mark in-progress so interruptions leave a clear state.
			if start == 0 {
				if err := state.Write(vp.StateFile, state.StateDestroying); err != nil {
					return err
				}
			}

			for i := start; i < len(steps); i++ {
				if err := steps[i].fn(c.Context()); err != nil {
					_ = state.WriteRecord(vp.StateFile, state.Record{
						State:          state.StateDestroyFailed,
						LastFailedStep: steps[i].id,
					})
					return fmt.Errorf("destroy failed at step %q: %w", steps[i].id, err)
				}
			}

			fmt.Fprintln(c.OutOrStdout(), "VM destroyed.")
			return nil
		},
	}
	cmd.Flags().BoolVar(&force, "force", false, "destroy even if the VM is currently running")
	cmd.Flags().BoolVar(&recover, "recover", false, "resume a DESTROY_FAILED sequence from where it left off")
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
	if ssh.ConfigFile == "" || ssh.ConfigFile == "/dev/null" {
		return nil
	}
	if _, err := os.Stat(ssh.ConfigFile); err != nil {
		return nil
	}

	cmd := exec.CommandContext(ctx, "rsync",
		"-aH",
		"-e", fmt.Sprintf("ssh -F %s", ssh.ConfigFile),
		ssh.Host+":/nix/store/",
		filepath.Join(warm.Dir, "store")+"/",
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
