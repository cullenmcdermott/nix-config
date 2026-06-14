package cli

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/bridge"
	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
)

func newBridgedCmd() *cobra.Command {
	var socket, token, credentials string
	cmd := &cobra.Command{
		Use:    "bridged",
		Hidden: true,
		Short:  "Internal: run the host bridge daemon for one VM",
		RunE: func(c *cobra.Command, _ []string) error {
			ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
			defer cancel()

			// Resolve the global config to pick up bridge.op_allow. A missing
			// config file is fine (LoadGlobal returns defaults); any other
			// error is fatal because silently running with an empty allowlist
			// would mask a misconfigured/corrupt config from the user.
			var opAllow []string
			if p, err := paths.Resolve(); err == nil {
				g, err := config.LoadGlobal(p.GlobalConfig)
				if err != nil {
					return err
				}
				opAllow = g.Bridge.OpAllow
			}

			h := &bridge.ProdHandlers{
				CredentialsPath: credentials,
				OpAllow:         opAllow,
			}
			s := bridge.NewServer(socket, token, h, 30*time.Second)
			return s.Serve(ctx)
		},
	}
	cmd.Flags().StringVar(&socket, "socket", "", "unix socket path (required)")
	cmd.Flags().StringVar(&token, "token", "", "session token (required)")
	cmd.Flags().StringVar(&credentials, "credentials", os.Getenv("HOME")+"/.claude/.credentials.json", "path to Claude credentials file")
	_ = cmd.MarkFlagRequired("socket")
	_ = cmd.MarkFlagRequired("token")
	return cmd
}
