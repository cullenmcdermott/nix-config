package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newShellCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:               "shell",
		Short:             "Open an interactive bash inside this project's VM",
		DisableFlagParsing: true,
		RunE: func(c *cobra.Command, args []string) error {
			id, err := vmid.ForCwd()
			if err != nil {
				return err
			}
			vp := app.Paths.VM(string(id))
			persisted, err := state.Read(vp.StateFile)
			if err != nil {
				return err
			}
			if persisted != state.StateRunning {
				return fmt.Errorf("VM is %s — run `sandbox start` first", persisted)
			}
			ssh, err := app.Backend.SSHConfig(c.Context(), backend.VMID(id))
			if err != nil {
				return err
			}
			forwards := []string{"/run/sandbox-bridge.sock:" + vp.BridgeSocket}
			return app.ExecSSH(ssh.ConfigFile, ssh.Host, forwards, args)
		},
	}
}
