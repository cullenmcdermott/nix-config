package cli

import (
	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

func newClaudeCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:                "claude [-- args...]",
		Short:              "Run Claude Code inside this project's VM",
		DisableFlagParsing: true,
		RunE: func(c *cobra.Command, args []string) error {
			id, err := app.SelectedVMID(c)
			if err != nil {
				return err
			}
			vp := app.Paths.VM(string(id))
			persisted, err := state.Read(vp.StateFile)
			if err != nil {
				return err
			}
			if persisted == state.StateNew || persisted == state.StateStopped {
				start := newStartCmd(app)
				start.SetContext(withNoWizard(c.Context(), true))
				start.SetOut(c.OutOrStdout())
				start.SetErr(c.ErrOrStderr())
				if err := start.RunE(start, nil); err != nil {
					return err
				}
			}
			ssh, err := app.Backend.SSHConfig(c.Context(), backend.VMID(id))
			if err != nil {
				return err
			}
			forwards := []string{"/run/sandbox-bridge.sock:" + vp.BridgeSocket}
			invoke := append([]string{"claude"}, args...)
			return app.ExecSSH(ssh.ConfigFile, ssh.Host, forwards, invoke)
		},
	}
}
