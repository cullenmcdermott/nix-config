package cli

import (
	"context"
	"fmt"
	"os"
	"os/user"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/lima"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

type noWizardKey struct{}

func withNoWizard(ctx context.Context, v bool) context.Context {
	return context.WithValue(ctx, noWizardKey{}, v)
}

func noWizard(ctx context.Context) bool {
	v, _ := ctx.Value(noWizardKey{}).(bool)
	return v
}

func shouldShowWizard(c *cobra.Command, perVMPath string) bool {
	if noWizard(c.Context()) {
		return false
	}
	if !isTTY() && os.Getenv("SANDBOX_FORCE_WIZARD") != "1" {
		return false
	}
	if _, err := os.Stat(perVMPath); err == nil {
		return false
	}
	return true
}

func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

func newStartCmd(app *App) *cobra.Command {
	var noWizardFlag bool
	cmd := &cobra.Command{
		Use:   "start",
		Short: "Create or resume this project's VM",
		RunE: func(c *cobra.Command, _ []string) error {
			ctx := withNoWizard(c.Context(), noWizardFlag)
			c.SetContext(ctx)
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
	cmd.Flags().BoolVar(&noWizardFlag, "no-wizard", false, "skip the first-run wizard and accept current defaults")
	return cmd
}

func doCreate(ctx context.Context, c *cobra.Command, app *App, id vmid.ID, statePath string) error {
	p := app.Paths
	vp := p.VM(string(id))

	if app.Wizard != nil && shouldShowWizard(c, vp.ConfigFile) {
		g, err := config.LoadGlobal(p.GlobalConfig)
		if err != nil {
			return err
		}
		v, err := app.Wizard(g)
		if err != nil {
			return fmt.Errorf("wizard: %w", err)
		}
		if err := os.MkdirAll(vp.ConfigDir, 0o755); err != nil {
			return err
		}
		if err := config.SavePerVM(vp.ConfigFile, v); err != nil {
			return err
		}
	}

	r, err := config.LoadResolved(p.GlobalConfig, vp.ConfigFile)
	if err != nil {
		return err
	}
	projectPath, err := vmid.ProjectPath()
	if err != nil {
		return err
	}
	mounts := BuildMounts(projectPath, app.Paths.Home, r.Mounts)

	provision, err := lima.RenderProvision(lima.ProvisionConfig{
		User:                currentUsername(),
		HostClaudeMountRoot: HostClaudeMountRoot,
	})
	if err != nil {
		return err
	}

	spec := backend.VMSpec{
		ID:        backend.VMID(id),
		CPUs:      r.CPUs,
		MemoryMiB: r.MemoryGiB * 1024,
		DiskGiB:   r.DiskGiB,
		Arch:      defaultArch(r.Arch),
		Mounts:    mounts,
		Provision: backend.ProvisionScript{Script: provision},
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

func doStart(_ context.Context, c *cobra.Command, app *App, id vmid.ID, statePath string) error {
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

func currentUsername() string {
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	if u, err := user.Current(); err == nil {
		return u.Username
	}
	return "user"
}
