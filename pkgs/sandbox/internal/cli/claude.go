package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
	"github.com/cullenmcdermott/system-config/sandbox/internal/state"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
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

			// Use the actual cwd, not the git root. The project is synced at
			// the same absolute path, so subdirectories are accessible in the VM.
			startDir, err := startingDir()
			if err != nil {
				return err
			}

			forwards := []string{"/run/sandbox/bridge.sock:" + vp.BridgeSocket}
			claudeCmd := buildClaudeSSHCmd(startDir, args)
			// SSH concatenates all post-hostname argv into a single string and
			// passes it to the user's remote shell via `$SHELL -c '<joined>'`.
			// We pass it as one element to avoid ambiguity.
			invoke := []string{claudeCmd}
			return app.ExecSSH(ssh.ConfigFile, ssh.Host, forwards, invoke)
		},
	}
}

// startingDir returns the directory claude should start in inside the VM.
// Prefers the literal cwd (so `sandbox claude` from a subdirectory lands
// there), falling back to the project root.
func startingDir() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return vmid.ProjectPath()
	}
	resolved, err := filepath.EvalSymlinks(cwd)
	if err != nil {
		return cwd, nil
	}
	return resolved, nil
}

// buildClaudeSSHCmd constructs a shell command string for SSH remote execution.
// The command:
//  1. sources /etc/profile for PATH setup (SSH non-login shell skips it)
//  2. cd's into the working directory
//  3. activates the project's flox environment (if one exists)
//  4. launches claude in --dangerously-skip-permissions mode
//
// The returned string is passed as a single SSH argv element. SSH joins all
// post-hostname args with spaces and passes them to `$SHELL -c '...'` on the
// remote side, so this must be a valid shell command at that single level of
// interpretation.
func buildClaudeSSHCmd(dir string, args []string) string {
	var parts []string

	// Source login profile so /usr/local/bin is on PATH.
	parts = append(parts, ". /etc/profile")

	// cd into the working directory.
	parts = append(parts, fmt.Sprintf("cd %s", shellQuote(dir)))

	// Activate flox environment if a .flox/ dir exists.
	// eval so the activation modifies the current shell's env.
	parts = append(parts, `if [ -d .flox ]; then eval "$(flox activate)"; fi`)

	// Launch claude with --dangerously-skip-permissions and any user args.
	claudeArgs := []string{"claude", "--dangerously-skip-permissions"}
	claudeArgs = append(claudeArgs, shellQuoteAll(args)...)
	parts = append(parts, "exec "+strings.Join(claudeArgs, " "))

	return strings.Join(parts, " && ")
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}

func shellQuoteAll(ss []string) []string {
	out := make([]string, len(ss))
	for i, s := range ss {
		out[i] = shellQuote(s)
	}
	return out
}
