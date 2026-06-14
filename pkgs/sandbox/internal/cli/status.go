package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"

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
			fmt.Fprintf(out, "  sync_git: %t\n", r.SyncGit)
			if len(r.Mounts) > 0 {
				fmt.Fprintf(out, "  mounts:\n")
				for _, m := range r.Mounts {
					mode := "read-only"
					if m.Writable {
						mode = "WRITABLE — the VM can modify this host directory"
					}
					fmt.Fprintf(out, "    - %s -> %s (%s)\n", m.HostPath, m.VMPath, mode)
				}
			}
			if app.Bridge != nil {
				fmt.Fprintf(out, "Bridge: %s\n", bridgeStatus(vp.DataDir, vp.BridgeSocket))
			}
			if app.Mutagen != nil {
				sessions, err := app.Mutagen.SessionsFor(c.Context(), string(id))
				if err == nil && len(sessions) > 0 {
					fmt.Fprintln(out, "Sync sessions:")
					for _, sess := range sessions {
						fmt.Fprintf(out, "  %s: %s", sess.Name, sess.Status)
						if sess.Conflicts > 0 {
							fmt.Fprintf(out, " (%d CONFLICTS — see `mutagen sync list %s`)", sess.Conflicts, sess.Name)
						}
						fmt.Fprintln(out)
					}
				}
			}
			return nil
		},
	}
}

// bridgeStatus reports liveness of the per-VM bridge daemon from its pid file
// and socket. Read-only: status must never kill or restart anything.
func bridgeStatus(dataDir, socketPath string) string {
	data, err := os.ReadFile(filepath.Join(dataDir, "bridge.pid"))
	if err != nil {
		return "not running"
	}
	var pid int
	_, _ = fmt.Sscanf(string(data), "%d", &pid)
	if pid <= 0 {
		return "not running (unparseable pid file)"
	}
	// Signal 0 probes process existence without sending anything.
	if err := syscall.Kill(pid, 0); err != nil {
		return fmt.Sprintf("not running (stale pid file, pid %d)", pid)
	}
	if _, err := os.Stat(socketPath); err != nil {
		return fmt.Sprintf("process alive (pid %d) but socket missing — restart with `sandbox stop && sandbox start`", pid)
	}
	return fmt.Sprintf("running (pid %d)", pid)
}
