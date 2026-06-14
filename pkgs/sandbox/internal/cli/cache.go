package cli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/nixcache"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newCacheCmd(app *App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cache",
		Short: "Manage the shared Nix binary cache",
	}
	cmd.AddCommand(newCacheSyncCmd(app))
	cmd.AddCommand(newCacheInfoCmd(app))
	return cmd
}

func newCacheSyncCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:   "sync",
		Short: "Copy /nix/store from the running VM into the shared host cache",
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
			if persisted != state.StateRunning {
				return fmt.Errorf("VM is %s — `sandbox cache sync` requires RUNNING", persisted)
			}
			return runCacheSync(c.Context(), c, app, id, false)
		},
	}
}

func newCacheInfoCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:   "info",
		Short: "Print information about the shared Nix binary cache",
		RunE: func(c *cobra.Command, _ []string) error {
			dir := app.Paths.NixCacheDir
			narinfos := 0
			var total int64
			err := filepath.Walk(dir, func(path string, info os.FileInfo, werr error) error {
				if werr != nil {
					if os.IsNotExist(werr) {
						return nil
					}
					return werr
				}
				if info.IsDir() {
					return nil
				}
				if strings.HasSuffix(info.Name(), ".narinfo") {
					narinfos++
				}
				total += info.Size()
				return nil
			})
			if err != nil && !os.IsNotExist(err) {
				return err
			}
			out := c.OutOrStdout()
			fmt.Fprintf(out, "cache dir:   %s\n", dir)
			fmt.Fprintf(out, "narinfos:    %d\n", narinfos)
			fmt.Fprintf(out, "total bytes: %d\n", total)
			return nil
		},
	}
}

// runCacheSync performs the host-side `nix copy` from the VM into the shared
// binary cache. It is shared between the user-facing `sandbox cache sync`
// command and the best-effort sync invoked by `sandbox stop` / `sandbox
// destroy`.
//
// When bestEffort is true, transport-layer failures (no usable SSH config, VM
// unreachable) are silently treated as no-ops, and `nix copy` failures are
// surfaced via the returned error so the caller can warn-and-continue. When
// bestEffort is false, every failure is returned as an error.
func runCacheSync(ctx context.Context, c *cobra.Command, app *App, id vmid.ID, bestEffort bool) error {
	ssh, err := app.Backend.SSHConfig(ctx, backend.VMID(id))
	if err != nil {
		if bestEffort {
			return nil
		}
		return err
	}
	if ssh.ConfigFile == "" || ssh.ConfigFile == "/dev/null" {
		if bestEffort {
			return nil
		}
		return fmt.Errorf("no usable SSH config for VM %s", id)
	}
	if _, err := os.Stat(ssh.ConfigFile); err != nil {
		if bestEffort {
			return nil
		}
		return err
	}

	cache, err := nixcache.Open(app.Paths.NixCacheDir)
	if err != nil {
		return err
	}
	if err := cache.Ensure(); err != nil {
		return err
	}
	if _, err := nixcache.EnsureKey(app.Paths.NixCacheKey); err != nil {
		return err
	}

	release, err := cache.Lock(ctx)
	if err != nil {
		return err
	}
	defer func() {
		if rerr := release(); rerr != nil {
			fmt.Fprintf(c.ErrOrStderr(), "warning: nix cache lock release failed: %v\n", rerr)
		}
	}()

	start := time.Now()
	if err := nixcache.Sync(ctx, ssh.ConfigFile, ssh.Host, app.Paths.NixCacheDir,
		c.OutOrStdout(), c.ErrOrStderr()); err != nil {
		return err
	}
	fmt.Fprintf(c.OutOrStdout(), "cache sync complete (%s)\n", time.Since(start).Round(time.Second))
	return nil
}

// syncCacheBestEffort runs a cache sync against the given VM and, on failure,
// emits a single warning line to stderr instead of returning the error. Used
// during `sandbox stop` and `sandbox destroy`, where the cache is an
// optimization and must not block the operation.
func syncCacheBestEffort(ctx context.Context, c *cobra.Command, app *App, id vmid.ID) {
	if err := runCacheSync(ctx, c, app, id, true); err != nil {
		fmt.Fprintf(c.ErrOrStderr(), "warning: nix cache sync failed (continuing): %v\n", err)
	}
}
