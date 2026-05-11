package cli

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
)

func newOmpCmd(app *App) *cobra.Command {
	return &cobra.Command{
		Use:                "omp [-- args...]",
		Short:              "Run Oh My Pi inside this project's VM",
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

			startDir, err := startingDir()
			if err != nil {
				return err
			}

			forwards := []string{"/run/sandbox/bridge.sock:" + vp.BridgeSocket}
			ompCmd := buildOmpSSHCmd(startDir, args)
			invoke := []string{ompCmd}
			return app.ExecSSH(ssh.ConfigFile, ssh.Host, forwards, invoke)
		},
	}
}

// buildOmpSSHCmd constructs a shell command string for SSH remote execution.
// The command:
//  1. sources /etc/profile for PATH setup (SSH non-login shell skips it)
//  2. cd's into the working directory
//  3. activates the project's flox environment (if one exists)
//  4. launches omp (no --dangerously-skip-permissions; omp does not have this flag)
func buildOmpSSHCmd(dir string, args []string) string {
	var parts []string

	parts = append(parts, ". /etc/profile")
	parts = append(parts, fmt.Sprintf("cd %s", shellQuote(dir)))
	parts = append(parts, `if [ -d .flox ]; then eval "$(flox activate)"; fi`)

	ompArgs := []string{"omp"}
	ompArgs = append(ompArgs, shellQuoteAll(args)...)
	parts = append(parts, "exec "+strings.Join(ompArgs, " "))

	return strings.Join(parts, " && ")
}