package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newStartCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:   "start",
		Short: "Create or resume this project's VM",
		RunE: func(c *cobra.Command, _ []string) error {
			ctx := c.Context()
			id, err := vmid.ForCwd()
			if err != nil {
				return err
			}
			vp := app.Paths.VM(string(id))

			// Persisted state is the source of truth for what to do.
			persisted, err := state.Read(vp.StateFile)
			if err != nil {
				return err
			}
			out := c.OutOrStdout()
			switch persisted {
			case state.StateRunning:
				fmt.Fprintln(out, "VM already running.")
				return nil
			case state.StateNew:
				return doCreate(ctx, c, app, id, vp.StateFile)
			case state.StateStopped:
				return doStart(ctx, c, app, id, vp.StateFile)
			case state.StateProvisioning, state.StateDestroying:
				return fmt.Errorf("VM is %s — wait or recover manually", persisted)
			case state.StateFailed:
				return fmt.Errorf("VM is FAILED — destroy and recreate")
			case state.StateDestroyFailed:
				return fmt.Errorf("VM is DESTROY_FAILED — manual cleanup required (see `sandbox status`)")
			default:
				return fmt.Errorf("VM in unexpected state %s", persisted)
			}
		},
	}
}

func doCreate(ctx interface{ Done() <-chan struct{} }, c *cobra.Command, app *App, id vmid.ID, statePath string) error {
	p := app.Paths
	vp := p.VM(string(id))
	r, err := config.LoadResolved(p.GlobalConfig, vp.ConfigFile)
	if err != nil {
		return err
	}
	spec := backend.VMSpec{
		ID:        backend.VMID(id),
		CPUs:      r.CPUs,
		MemoryMiB: r.MemoryGiB * 1024,
		DiskGiB:   r.DiskGiB,
		Arch:      defaultArch(r.Arch),
	}
	if err := state.Write(statePath, state.StateProvisioning); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "creating VM (first run)…")
	if err := app.Backend.Create(c.Context(), spec); err != nil {
		_ = state.Write(statePath, state.StateFailed)
		return fmt.Errorf("create: %w", err)
	}
	if err := state.Write(statePath, state.StateRunning); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "VM running.")
	return nil
}

func doStart(_ interface{ Done() <-chan struct{} }, c *cobra.Command, app *App, id vmid.ID, statePath string) error {
	fmt.Fprintln(c.OutOrStdout(), "starting VM…")
	if err := app.Backend.Start(c.Context(), backend.VMID(id)); err != nil {
		return fmt.Errorf("start: %w", err)
	}
	if err := state.Write(statePath, state.StateRunning); err != nil {
		return err
	}
	fmt.Fprintln(c.OutOrStdout(), "VM running.")
	return nil
}

// defaultArch returns the user's chosen arch, or "aarch64" if empty.
// Detecting host arch is deferred to Phase 4 (wizard); for now Apple Silicon
// is the only supported host.
func defaultArch(s string) string {
	if s == "" {
		return "aarch64"
	}
	return s
}
